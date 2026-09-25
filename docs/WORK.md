# Work record

[Home](../README.md) · [Profile](../PROJECT.md) ·
[Architecture and limits](ARCHITECTURE.md) · [Provenance](PROVENANCE.md)

## Objective and scope

Build Pythian into the Pascal ecosystem's reusable audio synthesis foundation:
first distill common WFC/Phanes audio behavior, then expand into a full suite of
fundamental synthesis tooling. Retain WFC as a companion with actual contract
adapters and learners. Extend learning from MIDI into WAV music, including an
audible generation path. Remove the temporary Phanes reference only after
extraction gates pass. Keep work native, focused, and proportional to risk.
The branch is `hello-pythian`; the namespace is `pythian`.

## Independent drum-source screen — 2026-09-23

Ticket Guy completed one frozen, metadata-only Pascal screen of the
[official Groove MIDI Dataset](https://magenta.withgoogle.com/datasets/groove)'s
MIDI-only archive. The exact archive and two selected
performances, from different drummers and sessions, pass the declared symbolic
gate: each has an explicit tempo and 4/4 clock, over 30 seconds of note events,
and paired audio named in publisher metadata. The publisher claims MIDI/audio
alignment within 2 ms, but no audio was opened or independently checked. MIDI
drum hits could provide a future source-event reference; the source has no
isolated audio stems or composition IDs in the inspected metadata. The policy,
Pascal analyzer, exact identities, report and zero-leak Win64 log remain under
ignored `build/gmd-pulse-source/`. This screen does not resolve the frozen
ARTBeaT 02/04 windows or close `NS-3_tempo_04`; no beat scoring, TensorFlow or
other inference runtime ran. Do not expand this into another source sweep while
the current note-render listening decision is pending.

## Physical pickup presence source stop — 2026-09-23

One distinct, prospectively frozen source strategy used GuitarSet's original
six-string pickup alongside the already reviewed player-05 microphone clips.
Pascal bound the reviewed clip windows, source hashes, six-channel PCM geometry
and publisher ZIP-member CRC. The supposed rest clip 9 had pickup pooled RMS
0.000150761, 23.4% of the quieter positive clip 8 rather than the frozen
maximum 10%; clip 7 was stronger. No presence score ran, and reserved player
00 was not opened. The full archive MD5 was not checked because only exact
member byte ranges were acquired. See
[physical source gate](PRESENCE.md#guitarset-physical-pickup-source-gate-stopped--2026-09-23)
and its ignored policy/report. This source/window/ratio is stopped; NS-3_notes_05
criterion 3 and milestone credit remain open. The failed 30-second generated
preview makes note identity, presence and event admission urgent, but repeated
unqualified rest searches cannot close them. Continue a different ready core
prerequisite while a genuinely qualified acoustic reference is absent.

## Full-recording presence source stop — 2026-09-23

The next bounded source-level gate used the complete isolated URMP Waltz flute
track under a policy fixed before scoring. Checked Pascal inspected 351
nonoverlapping 250-ms windows across the 92.79-second source. Seventy met
the positive annotation and PCM gates; no window met the independent
no-instrument rest gate. Of five note-free halo windows, three also had zero
F0 throughout, but their PCM RMS was 0.0093–0.0112 against a frozen 0.0001
rest maximum. No `pythian.presence` score ran. The independent Miserere work
was not opened. Exact identities, clock limits and the untracked result are
in [PRESENCE](PRESENCE.md#full-recording-isolated-stem-source-gate-stopped--2026-09-23).
Salty Boi's focused checked Win64 QA matched two complete report replays to
SHA-256 `ae07a08fa40fd68176ac31a2dde5cb45af7b69e35a998d1a71891d2a4b0cca4f`
with zero unfreed blocks and confirmed the source gate prevented scoring.

This and the Good-sounds metadata stop are two consecutive source-level batches
without a qualified combined reference. Stop both source routes. The changed
prerequisite is a recording or controlled capture with independently supported
**actual no-instrument acoustics** and work-disjoint positives; note/F0 gaps
alone cannot supply the generic rest contract. Keep any unavailable exact
window `unknown`, do not ask the user for more routine source labels, and
continue a different ready core task while this source gate remains open.
NS-3_notes_05 criterion 3 and the 68.65% total do not change.

## Substantial generated development preview — 2026-09-23

The previous source packet gate did not close recorded note admission, so the
next user-facing checkpoint exercises the already existing Pascal
recorded-WAV → saved WFC pitch/duration model → Pythian synthesis path. The
`generate-runs` operator now accepts a bounded `--spans` count and records it
in its report; the optional recorded-phrase workflow requests 256 spans and
uses a distinct preview filename, leaving historical eight-span diagnostics
intact. The existing Spring flute development model, learned from the first
30 seconds of its source, yielded a 256-span, 140-note, 1,339,758-frame stereo
44.1-kHz WAV (30.38 seconds) with SHA-256
`5039ed361649d1fb9f76eb810dcfb4ff39ba0cc0ac1ccabc5d5bc610bce96b95`
under ignored `build/recorded-preview-3.2.2-win32/`. The model SHA-256 is
`2c6efca0f2a77c817fd83a1f793521955d6a5bfe15a43c3b1419de6e4a8998e6`;
seed 731 and a 10-ms duration quantum are fixed. Focused CLI QA passed. This
is an automatic, development-exposed
note-model preview with authored voice/velocity; it is not accepted
transcription, flute timbre, recorded-note accuracy, genre learning, or
milestone credit. The reserved recording groups remain untouched.

The old command form defaults to eight spans and matches explicit `--spans 8`
on current source with WAV SHA-256
`1005e073771ff29fd5b2b45cf5707ff4137113f08fa8fd4c6db24c2741810002`. An older
precompiled Win32 operator reproduces the saved historical eight-span WAV hash
`bd277c1d6b6130af1f9fec9b1dbc889e9fa14549a3acf1644e2c8aafdf0ba62d`; fresh
current-source output differs while retaining the same model hash, seed,
eight states/notes and 26,901 frames. This validates current CLI/default
compatibility, not byte identity with that older executable. Checked stable FPC
3.2.2 Win32/Win64 reject malformed `--spans zero` with exit 1, no output and
zero unfreed blocks. Repeated 256-span runs match across targets (SHA-256
`5039ed361649d1fb9f76eb810dcfb4ff39ba0cc0ac1ccabc5d5bc610bce96b95`); all 116
unknown spans are exact PCM silence, alongside 140 pitch spans. The user's
full-clip review said it has "the very early beginnings of something musical"
but "trips over notes almost throughout the entirety of the track." This
fails the substantial musical-quality checkpoint. The user later clarified
that both pitch jumps and uneven timing contribute to the stumbling. Preserve
this exact source/model/seed/WAV as a development failure; prioritize note identity,
presence and event decisions before another length or timbre variation. The
numbered HFS copy was removed after the reply; the original ignored WAV and
report remain.

The first private annotation-versus-extraction comparison packet stopped before
rendering: published Spring flute note rows 6 and 7 overlap by 1 ms
(`3.048+0.159 > 3.206`), violating its frozen monophonic-input gate. Checked
Pascal compilation passed; no new audio, saved model or listening verdict
followed. Its policy and exact error remain under ignored
`build/annotation-pair/`. One revised, predeclared packet permits the later
onset to own a bounded overlap **only in the monophonic training model** while
preserving original intervals in a direct native render. It stops if any overlap
exceeds 10 ms, total clipping exceeds 100 ms, or quantization collapses a note.
This diagnostic can distinguish a renderer/timing failure from failures in
WAV note extraction or generated sequence modeling; it is not task acceptance.
The revised checked Win64 Pascal packet passed its fixed bounds on the
development-exposed first 30 seconds: 96 published note rows, four 1-ms
overlaps clipped **only for monophonic WFC training** (4 ms total), and 164
contiguous 10-ms model spans. The direct Pythian render retains the published
intervals and is exactly 30 seconds, stereo 44.1 kHz, SHA-256
`c168dac24cb94b0dd45b4d72af4b02c2ad388bc6f94166565ede537d55913fda`.
The saved annotation-conditioned model SHA-256 is
`e11c2feb6163feef68fcc629b8cdf740b771ae945a21994ae956585473804bbb`;
the unchanged native `generate-runs` consumer used seed 731, 10-ms quantum
and 256 spans to make a 42.9-second WAV, SHA-256
`5e840a97945496cdaf91cd69d9d8549f7a3144b9ae81f957f63daf797c96e871`.
One heap-traced replay matched the direct/model hashes with zero unfreed
blocks. The private policy, Pascal tool, full ledger and WAVs are ignored under
`build/annotation-pair/`. Salty Boi's checked stable FPC 3.2.2 Win32/Win64 QA
verified both source identities, the four exact 1-ms model-only clips, direct
original intervals, output geometry, failure preservation and zero leaks.
The 256-span generated WAV and JSON sidecar replay byte-identically across
targets. The private diagnostic report includes elapsed time and tiny
target-dependent cents residual formatting, so its bytes are not a cross-target
replay claim. The existing extraction-trained input had 135 pitch spans and
12.56 seconds of unknown; the published-note model has 96 pitch spans and
9.28 seconds of annotation gaps, with no unknown. These are descriptive
training facts, not a musical verdict. Three hash-verified WAV copies are
temporarily available in the existing local HFS feedback folder as numbered
clips 1–3. The user judged both new clips as stumbling. The direct render's
failure means the reference annotations plus the current solo voice and
articulation are not a positive musical control; WFC sequencing alone cannot
explain the shared result. The separate contribution of source performance,
solo-part context and rendering is still unknown. Both clips fail this musical
checkpoint, with no recorded-note admission or independent-phrase credit.
Neither annotation-conditioned output is automatic WAV transcription. The
answered HFS copies could not be removed: automatic command review rejected
the exact three-file deletion. The original ignored outputs remain available.

The failed original preview and solo published-note comparison were two
nonclosing musical-control batches. A changed, one-variant control under
ignored `build/reference-two-part/` combines the exposed Spring flute and
violin publisher notes at their exact first-30-second times, with two authored
voices and no WFC or source audio. Its frozen plan binds both Notes hashes,
articulation, gain/pan and a no-clipping gate. Checked FPC 3.2.2 Win32/Win64
QA confirmed 96 flute plus 91 violin gates, 30-second stereo 44.1-kHz PCM16,
peak 0.08048195, WAV SHA-256
`531da1df81ef9c2dfc8ad958f27bc5350c6735cb4cc2c59135c61deb2df465b5`,
byte-identical replay and zero leaks. A copied-input hash-failure check found
an uncaught-exception leak; the private probe now exits 1, preserves existing
outputs and reports zero leaks. The hash-verified HFS copy is
`build/feedback/4.wav`. The user heard **no stumbling** and identified the
song as pre-authored, correctly: this exact-note replay is neither unique
generation nor WAV inference. Added part context or changed voice balance may
explain the solo contrast. Stop this control without task credit. The next
musical checkpoint needs new generated note choices across parts, with learned
and authored contributions explicit.

## Recalibrated execution focus — 2026-09-23

The user wants progress measured by a substantial Pythian result, with their
listening time spent on generated audio. The bounded synthesis and WFC layer
contracts are accepted; recorded note admission is the next critical path.
Stop routine source microclip requests and repeated single-window or threshold
investigations. After the development listening preview above, the next
evidence deliverable is one qualified recording-grouped reference packet
suitable for the existing register and presence tasks, with
publisher method, known errors, acoustic labels and untouched groups explicit.
If no source passes the declared evidence gate, stop before another scorer
attempt and reassess the source strategy. Then move through presence/register,
event decisions and saved phrase learning toward an accepted native generated
listening checkpoint. Preserve each task's complete criteria and the current
68.65% acceptance total; the roadmap change earns no credit.

The first source-level gate screened the publisher's
[Good-sounds 1.1](https://zenodo.org/records/4588740) metadata before its
13.9-GB audio archive. Official `sounds.json`, `takes.json` and `packs.json`
MD5 values matched the downloaded files. A private Pascal scan found 8,750
sound rows, but only 279 complete attack/release/offset triplets: 79 flute
from one player, 100 clarinet from one player and 100 trumpet from one player.
No violin row had all three marks. This cannot supply the planned independent
player combined register/presence packet. The archive transfer then measured
about 0.26 MB/s, so it was stopped after about 3 MB; no audio was extracted
or scored. The incomplete ignored archive remains after a single-file
deletion command was rejected by automatic review. Good-sounds may still be
useful for register-only development because its broader metadata has three
flute and two violin players, but its phase marks cannot support the proposed
combined packet. This is one nonclosing source gate; do not promote metadata
to audible-rest truth or spend further time on this archive route without a
new access/evidence plan.

Accepted musical architecture: use WFC passes for small, granular layers, with
base key/tempo context informing harmony/rhythm and higher voice parts. Style
learned from one or several songs must be reusable for generation and subsequent
selective blends/merges. Retain per-layer control, compatible vocabulary/time
contracts, joint relationships and derived source lineage. Core fundamentals
remain the priority. [Layered style](LAYERED-STYLE.md) separates present mechanisms
from planned semantic providers, profile persistence, weighting and blend APIs.

## Listening effort and dataset-quality direction — 2026-09-23

The user clarified that dataset-label quality should come primarily from the
source and our evidence audit, while their ears should be spent on Pythian's
**synthesized results**. The twelve GuitarSet microclip labels already supplied
remain valid packet evidence; do not request the previously proposed next
eight routine source-clip labels. The mobile feedback folder stays empty until
a substantial generated listening checkpoint is ready. This changes the
evidence path, not the NS-3_notes_05 acceptance threshold: unknown source
windows stay unknown rather than receiving inferred human labels.

GuitarSet's [authors' paper](https://guitarset.weebly.com/uploads/1/2/1/6/121620128/xi_ismir_2018.pdf)
describes manually validated onsets from individual-string pickup recordings,
but automatically estimated note offsets. Its separately recorded microphone
is the audio Pythian tested. The [publisher release](https://zenodo.org/records/3371780)
also records known timing and duplicate-note errors. Thus the dataset is useful
for performed-note timing and source provenance, but the annotation end alone
cannot label a microphone window inaudible; the user confirmed guitar sound
after one such end. For the open recorded-presence criterion, first qualify
publisher-supported or otherwise independently grounded acoustic positive and
negative intervals, with source identity, capture relationship, annotation
method, known errors and held-out groups checked in Pascal. If that evidence
does not establish an exact-window rest, report the limitation and advance a
different ready core prerequisite rather than recruit the user as a routine
dataset annotator. Reserve their next listening review for generated output.

## Stem-supported presence source stop — 2026-09-23

The new dataset-quality path tested physical source contribution without
asking the user to label more recordings. The fixed, previously exposed URMP
Nocturne flute source had a valid 250-ms annotated flute-note interior, but a
checked Pascal annotation screen found no 250-ms flute rest with a half-second
halo while violin or clarinet covered it in the first 30 seconds. Two exact
metadata replays stopped before PCM, with zero leaks. No natural source-local
rest label followed.

A separate prospective control used the same `[35264,39264)` 16-kHz source
frames from three hash-bound recorded stems. The reference was a fixed
violin+clarinet background; the candidate added the flute stem to those exact
background frames. Checked stable Pascal Win32/Win64 verified hashes, geometry,
nonzero levels, no clipping and sample-wise difference. Background RMS was
0.008132706; adding flute RMS 0.003010764 raised total RMS only to
0.008577905 (ratio 1.054741761). The first frozen runner incorrectly marked
the violin+clarinet comparison window as a reviewed generic-instrument rest.
That `compatible_with_reviewed_rest` report is invalid: the comparison already
contains instruments. The corrected Pascal Win32/Win64 replay marks the
reference unreviewed and produces byte-identical `unknown` reports (SHA-256
`deb3edfb626e981e113dde70ce053ffeee788ab23d34b6f8f0e89e0972dfdaa7`),
with zero leaks. This pair verifies a physical source addition and a modest
mix-RMS change; it is neither a valid generic presence rest comparison nor a
human-audible or natural-recording accuracy result.

These are two nonclosing batches. Stop this composition without a new window,
gain or threshold. Reassessment: the next presence reference must be a
genuine no-instrument rest with independent acoustic support; an omitted part
under active accompaniment belongs to later part ownership, not this generic
presence reference. Neither the URMP metadata gap nor the controlled pair
supplies that rest. Meanwhile follow a different ready core prerequisite
rather than ask for routine user microclip labels. Criterion 3 and task credit
remain open.

The published MedleyDB stem-activation route was screened but not acquired:
its publisher says the activity labels are envelope-derived without manual
correction, and some stems contain bleed. It does not independently settle
exact-window audible rest for this task. See [presence evidence](PRESENCE.md#stem-supported-source-contribution-control--2026-09-23).

## Presence onset stop and fresh player-03 result — 2026-09-23

NS-3_notes_05 criterion 3 lacked a guitar-positive development window and a
fresh independent source. A frozen, two-aid follow-up selected
the first 250 ms after each already selected player-01/02 note onset, with a
no-other-annotated-note gate. Checked stable Pascal rejected an overlapping
note before either onset PCM window was read or any aid or score was made;
it reported zero leaks. The selection is stopped without moving a window.

Reassessment uses the already exposed player-05 packet as **development**
evidence: it has a user-identified guitar-positive contrast candidate and an
abstained guitar-positive window against an inaudible same-source reference.
Player 05 is not fresh evaluation evidence after a changed rule. The original
player-01/02 reviewed no-guitar windows remain development controls. For a
fresh independent check, the frozen metadata-only selection chose player 03,
`03_Rock2-85-F_solo`, disjoint in player and material from those three groups.
Its first eligible isolated end fixes windows [156605,167630),
[167630,178655) and [178655,189680). The checked Pascal JAMS hash/geometry/
overlap gate passed before mic extraction. The extracted mono PCM16 44.1-kHz
WAV has 1,992,138 frames and SHA-256
`6cef0f0edd3f3edfe0096280e68834024b5f35a754a6f075982daaf774f14b2a`.

Three unchanged-gain repeated aids numbered 12–14 passed exact source-PCM
and zero-gap verification on checked stable Win32/Win64, with byte-identical
manifest SHA-256
`879a1e81180c3690d9e945805468fe9b7dafb09f51783f9868b7c6d713b0c934`
and zero leaks. Private ignored policy files freeze the lowest-numbered
listener-confirmed same-source no-guitar reference, the unchanged
`pythian.presence.rest-contrast.v1` ratios, stop gates and one independent
score before review. Checked Win32/Win64 Pascal binders preflighted all three
aid hashes, and the source-bound scorer compiled on both targets. The user
reviewed all three numbered aids: 12 sounded guitar-like, 13 like guitar with
slackened strings, and 14 like sliding on guitar strings. The three labels are
`guitar`; none is a listener-confirmed same-source no-guitar reference.

Both checked Pascal binders produced byte-identical reviewed packets (SHA-256
`f15b461752b4e0192a7a6a983fe7ef856ad0fe86cc0c34ded7b4ae77cff45c7b`)
with zero leaks. The frozen Win32/Win64 scorer reports are also identical
(SHA-256 `123d517bdecc7eb4a0836cc92e032b2e69e5b7faa4b55419be10c23a2fb06deb`):
all three windows are `not_observed`/`no_reference`; there were no presence
inference decisions, misses, or independent acoustic result. Player 03 is now
exposed. The public mobile feedback copies were removed after binding; original
evidence remains in ignored `build/`.

This and the failed development-onset gate are two consecutive nonclosing
batches. The onset attempt could not supply a guitar-positive development
window because another annotated note overlapped the frozen interval. The
player-03 attempt supplied guitar-positive sound, but its adjacent post-end
windows remained guitar-like and could not supply a reviewed rest. Reassessment:
finish a **bounded source-local reference deliverable** using a materially
different annotation-gap selection, not another immediate post-end tail.
Freeze one new player/material-disjoint source and a distant candidate rest
window before opening its PCM; require an annotation-free interval and a
listener-confirmed no-guitar label before any presence score. Stop after one
source if the metadata gate fails or the listener again hears guitar in every
window. No ratio or window adjustment on that source. Criterion 3 and task
credit remain open.

The fixed player-04 BN2-166-Ab distant-gap screen then stopped at its
annotation-only gate. Checked stable FPC 3.2.2 Win32 Pascal verified the JAMS
SHA-256 and 48 note extents but found no event with a 250-ms final-note
window and a 1.0–1.25-second post-end window free of other annotated notes.
It reported zero leaks. No microphone PCM, listening aid, label or presence
score was produced. That source/window policy is closed; numbers 15 and 16
were not issued. The next source-grounded decision must qualify a recording
with both a recognizable guitar interval and a genuinely quiet/no-guitar
interval before reserving another independent evaluation packet. Annotation
silence alone remains insufficient. Criterion 3 and task credit remain open.

## First real GuitarSet presence review and score — 2026-09-23

The user reviewed the nine frozen repeated microphone aids and clarified
that clips 1, 4, 5 and 6 sounded piano/keyboard-like rather than guitar.
They heard nothing in 2, 3 and 9, and acoustic guitar in 7 and 8. The raw
reply and clarification are separate from a normalized, ignored label TSV;
`other_noise` means audible sound without user-identified guitar, not a
physical piano-source claim. Its SHA-256 is
`e9297a00220e433b794d9783767a561bcf23b66e67396e35e73cef2a15957131`.
Checked stable Pascal Win32/Win64 binders reverified all nine aid hashes and
emitted identical reviewed packet SHA-256
`22e8589b58fe2ed54afeeb839fae076eebd154648461503fe35c5d2cb913aa7c`,
with zero leaks.

The frozen production scorer used the lowest-numbered reviewed same-source
no-guitar comparisons 1, 4 and 9; it rechecked the listener inputs, aid
manifest and original WAV identities before writing output. Checked stable
Win32/Win64 development reports are byte-identical (SHA-256
`05bd16a0e0986c8918325ea85148d72c4f0d58cce10ee24dadbaf99af11e288a`):
four scored windows were compatible with those no-guitar comparisons, with no
false active, missed active or abstention under that historical target-relative
scoring; two reference windows were excluded. Clips 1 and 4 were audible
`other_noise`, so their `compatible_with_reviewed_rest` outputs do not qualify
as generic-instrument presence decisions under the maintained API. The reserved
player-05 source ran once on checked Win64 (SHA-256
`9f8dbd121eb3379f8f43e435d4b3ffee3ddecd22ccd974ce326b49cb47724779`):
guitar-positive clip 7 was a correct contrast candidate and guitar-positive
clip 8 was `unknown`, an explicit abstention. Clip 9 was the reference and
excluded. All scorers reported zero leaks. No ratios were retuned.

This closes [NS-3_notes_05](TODO/NS-3_notes_05.md) criterion 1's
source-bound listener-label and group convention at the declared packet scope;
only clip 9 is a reviewed no-instrument rest in this packet. Criteria 2 and 4
had already passed their maintained observation/consumer
scope. Criterion 3 and task credit remain open. There are no scored
guitar-positive development windows, so this packet cannot calibrate
positive sensitivity. The independent positive has one candidate and one
abstention, and player 05 is now exposed for any future policy change.
The next bounded deliverable must supply prospectively selected, user-reviewed
guitar-positive **development** and same-source no-guitar reference cases;
reserve a fresh independent source before adopting any changed decision.
Selection should target attack/continuation sounds that are recognizable to
the listener and leave the frozen fourfold/1.5-fold ratios unchanged.

## Acoustic-flute octave source gate — 2026-09-23

With the reviewed GuitarSet packet still pending, a separate non-listening
source feasibility check asked whether approved NSynth metadata could provide
instrument-disjoint acoustic-flute octave contrasts for
[NS-3_notes_01](TODO/NS-3_notes_01.md) criterion 1. Its fixed deliverable was
an exact metadata inventory, not a register inference result. The gate
required three train instruments and one test instrument, same-instrument
pitch pairs an octave apart in 48..84 at velocity 75 or 100, excluding the
flute group already reserved for presence evaluation. Failure would stop
before audio extraction or a new model experiment.

The ignored Pascal inventory verified each metadata JSON's full SHA-256
before and after scanning. Checked stable Win32/Win64 source-free parser
controls pass with zero leaks. The checked Win64 full scan found 6,362 train
flute IDs and 783 eligible pairs from 33 train instruments, but the 55 test
flute IDs supplied **no eligible pair**. The fixed split gate fails; stop this
NSynth register-source route without lowering its selection bounds or
substituting train material as independent test. The exact private pair TSV
SHA-256 is `1e1d582dcfcc1bf2badd467a89a3f534995be6a091cff1bd08b2518605794de7`.
No source audio, inference runtime or protected Spring evaluation was opened.
No criterion or task credit closes. The next core input remains the existing
independently reviewed acoustic note-presence packet; register work still
needs a distinct contrasting observation with fixed ambiguity and low/quiet/
short-note protections. This metadata failure cannot justify another octave
threshold or ranker variation.

## Score-aligned development note reference — 2026-09-23

With listening temporarily unavailable, the next non-listening batch advanced
[NS-3_context_01](TODO/NS-3_context_01.md) criterion 2 preparation. The
deliverable was an exact source-bound development note/measure packet from the
published archive already qualified for local-key work. The stop condition was
any missing or changed archive entry, CSV/WAV identity, source geometry, schema,
time/order, pitch or row cap; no key scoring was authorized in this batch.

The ignored Pascal selector extracted only four exact D911-02/16 HU33 entries
after verifying the complete archive. A predeclared parser policy then bound
each CSV and original WAV by SHA-256, decoded both original 22,050-Hz mono
PCM16 clocks, and emitted 1,640 original-score note rows plus 102 measure
anchors in original source-frame coordinates. Development groups have 943/697
notes, 53/49 measure anchors, 750/587 piano and 193/110 voice rows. Overlap
rows are retained, with no exact duplicate rows. Checked stable FPC 3.2.2
Win32/Win64 controls and bound TSVs agree byte for byte; note and measure TSV
SHA-256 values are `ba764aef1c76bb9407e3661e7b034d39746bc39214d69f7dffdc699ac6232520`
and `4f005081f5745d7a8cf10d137e40b42bb695ec56a825c3c91dc0380562f7ab91`.
Both runs report zero unfreed blocks. A tampered CSV rejects before output and
also reports zero leaks. The D911-05/19 evaluation sources stayed unopened.

This closes only the packet preparation, not an acceptance criterion: aligned
score events are not verified acoustic note presence or key truth. The previous
source-rate and stopped note-aware candidate batches were nonclosing; the
task-flow reassessment had already stopped variants. This distinct
reference-side path can support one prospectively gated development
observation comparison, but no inference variant or threshold is yet selected.
Criterion 2, independent evaluation and native delivery remain open; no task
credit changes. The GuitarSet listener packet also remains pending. Next
deliverable: declare a single source-grounded acoustic observation hypothesis
with fixed work and failure gates before any new development score. If it
cannot distinguish activity/timbre and tonic evidence, stop that path; retain
the listener review for when the user is available.

## Local-key note-interior screen and stop — 2026-09-23

The next bounded [NS-3_context_01](TODO/NS-3_context_01.md) criterion 2
screen tested one decision: whether the unchanged Pascal sparse-peak
observation separates score-aligned notes from an absent neighboring pitch
at safe note interiors. Its private prospective policy fixed source roles,
duration/edge/distance eligibility, top-12 and paired-separation measures,
50-note/40-pair cohort minima, 80%/75% support limits and 60-second/128-MiB
work bounds before any source score. It saved native observations and all
72 pitch summaries before reading the bound score TSV. No score label entered
inference, and no stopped key rule was retuned.

Checked stable Win32/Win64 source-free controls passed with zero leaks. The
first development WAV, D911-02 HU33, completed 1,012 native observations in
8,937 ms at 10,170,368 peak working-set and 3,973,120 private bytes on
checked Win64; the run reported zero leaks. Piano had 135 eligible notes,
123 nonzero top-12 pitches, and 131/135 separated adjacent pairs. Voice had
36 eligible notes and 35 pairs, below both fixed 50/40 minima; its 34/36
top-12 and 32/35 separation ratios cannot qualify the cohort. The screen
is inconclusive and stopped before D911-16 or held-out sources. The raw
observation SHA-256 is
`8d523f4b167e07c60f9c3b4e8c739b0c8d22185b882ea48c9cfb11861fae33a6`;
the pre-reference pitch-summary hash is
`df957ffa76f4f78d3039d9319d4b8496a39cdc9dd5446292d30e323c0f10fae3`.

The score-reference binding and this inconclusive screen are two consecutive
batches without closing another acceptance criterion. Under the task-flow
checkpoint, stop this local-key investigation sequence. Do not relax the
short-note eligibility after observing the count or resume ranker/profile
variants. The next action is the existing independently reviewed acoustic
activity reference in [NS-3_notes_05](TODO/NS-3_notes_05.md); only then
declare a genuinely different key-observation hypothesis with a fixed gate.
The user cannot listen at this checkpoint, so the nine-clip GuitarSet review
remains pending. No key accuracy, task credit or held-out claim follows.

## Maintained presence observation boundary — 2026-09-23

The ignored Pascal score runner's binding guard was tightened before any
recorded labels arrived. Its production build now requires the frozen
manifest, every original aid hash and the normalized listener-label TSV, and
checks every reviewed row against both inputs before opening a source WAV.
Two distinct synthetic packets still replay byte-identically on checked
stable Win32/Win64, including correct, error, abstention and no-reference
routes, with zero unfreed blocks. Current fixture-1 development/evaluation
TSV SHA-256 values are
`8d09e3cca59c2bffae3a3723e6e72df305396448880f3df8b8e0e72b39ed39ae`
and `69f8de349f582bfa2046de5628d4c560984d184106cc67af5e1efe69bdfec5c2`.
Wrong listener input, manifest, reviewed label and source WAV each reject
before output; the production build rejects the synthetic manifest. This
repairs a path where a self-hashed synthetic review could previously reach the
private scorer without independent binding. No real listener packet or
GuitarSet score exists yet.

Fresh focused stable FPC 3.2.2 Win32/Win64 checks accept the maintained
observation API and native consumer criteria of
[NS-3_notes_05](TODO/NS-3_notes_05.md). Both targets pass the exact-window,
unknown, work-cap, long-coordinate, failure-preservation and source-free
signal controls with zero unfreed blocks. The hash-bound 264,000-frame,
24-kHz stereo consumer WAV yields identical TSV bytes on both targets
(SHA-256 `22639cfffd9a372c9aed7bbdfaa5cd0a10196b18ac2e9ca4aa0ddc803c08b327`):
its 100,000-frame candidate crosses the reader chunk and retains `unknown`
for an unreviewed rest. The inspector now rehashes the full source after
observation and before emitting TSV, detecting any source change that persists
through that check; this adds a second full-file hash per call.
Fresh checked Win32/Win64 consumer builds retain the exact TSV replay and
zero unfreed blocks. The wrong-hash invocation exits before TSV output.
The [Ubuntu 24.04 push CI at `5651fef`](https://github.com/mr-highball/pythian/actions/runs/35923540295)
passed its FPC 3.2.2 native build and extracted core/WFC package checks.
That run compiles the inspector; its exact-window runtime check above remains
Win32/Win64 evidence.
This closes criteria 2 and 4 at their declared scope, without assigning
acoustic audibility, event accuracy or task credit. Criteria 1 and 3 still
need source-grounded labels and recorded development/independent results.

The scorer uses separate development and reserved-evaluation modes, verifies
each original mic WAV SHA-256 before and after scoring, chooses only the
lowest-numbered same-source listener-confirmed no-guitar rest, and counts
unknown-label, no-reference and excluded-reference windows apart from errors.
These mechanics are synthetic-tested only. The real binder has not run; no
GuitarSet label, rest reference, score or task credit exists yet.

The recorded listening packet's private Pascal review binder now passes
checked stable Win32/Win64 read-only preflight against the frozen manifest
and all nine aid SHA256 values, with zero unfreed blocks. Bind mode requires
exactly nine ordered labels in the fixed vocabulary and preserves input and
manifest hashes, but no user labels have arrived and it has not run. The fixed
scoring policy was written before labels: only a listener-confirmed no-guitar
window from the same recording can become its rest reference; player 05 is not
used for tuning. Packet preparation stops here rather than generating more clip
variants. The next dependency is the user's one-pass labels; until then no
recorded score or task credit follows. This is an external listening need for
the current NS-3_notes_05 packet, not a completion claim for the overall goal.

After delivering the observation API, a new source-bound GuitarSet listening
packet froze three recording IDs, note-event coordinates, roles and nine exact
windows before microphone extraction. The stopped player-00 packet was not
relaxed. Player 05 is now reserved for acoustic evaluation from a different
player and broad musical family; its annotation eligibility was previously
exposed, but its microphone audio, listening labels and inference scores were
not. Checked Pascal reverified both archive hashes, all three selected JAMS
hashes, mic WAV hashes and 44.1-kHz mono PCM16 geometry. A Pascal aid generator
made nine unchanged-gain 250-ms slices, repeated four times with silent gaps;
it checked every repeated PCM segment against its source. Checked stable
Win32/Win64 manifests match SHA256
`7151d48e59515633f0e2ac02a9f932581a254de7370de2a68a2d5c5b1d04c91c`
with zero unfreed blocks. The ignored packet lives under
`build/presence-recorded-packet/`. Direct acoustic labels are pending; no
presence scorer or independent result has run on the packet. The next gate is
one mobile listening review for guitar, other noise, nothing or uncertain in
each exact window. If the third recording is later scored, its metadata
exposure must be disclosed and it must not be used for tuning.

The reassessed batch implemented a maintained Pascal observation boundary,
[PRESENCE](PRESENCE.md), instead of running another source selector. The new
clip/streaming API measures exact candidate and disjoint same-recording
reference windows in source frames; it retains 64-bit source geometry,
policy identity, RMS/peak/envelope evidence, reviewed-reference identity and
explicit unknown. The `reviewed` flag is a caller assertion, not an acoustic
label inferred from annotations. The native WAV inspector verifies SHA256
before emitting TSV. Checked stable FPC 3.2.2 Win32/Win64 focused controls
passed with zero unfreed blocks, including source-frame coordinates beyond
32-bit range and partial-read failure preservation. Both targets produced
the same row on a hash-bound 100,000-frame stereo synthetic WAV window,
crossing the reader's 65,536-frame chunks and retaining `unknown` for an
unreviewed reference. A wrong SHA256 rejected before output. No recorded
instrument audibility or note/event accuracy is inferred. A 30-ms 55-Hz sine
at peak 0.005 reports `unknown` against the 0.001-RMS reference; the unit
retains its nonzero RMS, and the fixed fourfold ratio was not retuned.
Calibration,
independent cases, source-grounded labels and QA acceptance remain open, with
no task credit yet.

## Recorded presence source path — 2026-09-23

The subsequent NS-3_notes_05 GuitarSet source-wide packet froze a
player/material-separated role policy before scanning the retained annotation
ZIP. Checked stable Win64 Pascal audited all 360 JAMS members, excluding three
publisher-named errors, and reported 73 recordings with at least two fully
isolated three-window note-end candidates. Counts by player 00–05 were
0/6/9/16/16/26. Reserved player 00 could not supply the independent role.
The packet stopped before microphone extraction, listening, or scoring; no
selection file was written. Source archive SHA256 was
`8daa02e6417ccca1685feb44b135e95928ad7037e5032ecb326b5791856fda99`;
the ignored eligibility TSV SHA256 was
`9b5737189f1dc8796b19d77957163231d202162371345a44e86e9a38ab0a3055`.
The checked selector reported zero unfreed blocks. This is the second
consecutive nonclosing NS-3_notes_05 source batch after the two-recording
inventory. Reassess per task flow: the next deliverable is the maintained
pitch-independent evidence/unknown contract with source-free controls, rather
than another recording selector. Recorded calibration and independent cases
remain open and cannot borrow an acoustic label from annotation geometry.

The first NS-3_notes_02 batch after its accepted reference prerequisite tried
to prepare an extra source-separated development packet without touching its
independent NSynth train evaluation rows. An ignored pre-audio policy fixed the
original acoustic/quality filter, lexical note selection, two distinct
long-release families, exposure exclusions and exact windows. A checked stable
Win64 Pascal metadata selector found nine positive and 54 negative eligible
instruments overall, but no positive pair after the exclusions. It stopped
before a selection file, WAV extraction, listening or scoring. The failed
selector's unhandled exception reported 192 private bytes unfreed; it is not
a maintained tool. Do not widen that stopped selection or retune the default
activity floor against the independent flute miss. A second frozen path tried
the already source-bound URMP development cohorts: the checked Win64 Pascal
selector verified both stem WAV and note identities but found no post-end
candidate for the first required violin stem. It wrote no selection file,
decoded no audio and requested no review. Annotation ends remain separate from
acoustic audibility. Both attempts are nonclosing batches. At the task-flow
checkpoint, the oversized original three-point event task is split into the
independently useful [source-grounded presence observation](TODO/NS-3_notes_05.md)
(1 NS-3 goal point) and [event integration](TODO/NS-3_notes_02.md)
(2 points). The accepted one-point reference is unchanged. NS-3 remains 41%,
overall 68.65%, with 16 open NS-3 tasks and 36 total open tasks. The next
bounded action was a read-only source inventory for independently supported
recorded activity/unknown labels, not another variant of either stopped
selector. The [GuitarSet publisher](https://guitarset.weebly.com/) records
separate hexaphonic pickup and microphone paths, 360 excerpts from six
players, and JAMS note annotations. Existing local source archives and two
development-player mic WAVs were inspected with checked stable Win64 Pascal:
both are 44.1-kHz mono PCM16, 984,506 frames; the retained annotation ZIP
yielded two JAMS members with 17 parsed annotations each. The prior native
feasibility audit has six/two preliminary note-onset-gap candidates, without
excluding another note that sustains into a proposed rest. This is a
genuinely different recorded source route with actual acoustic listening
potential; annotation ends and null confidence fields are not acoustic truth.
Checked Win64 Pascal then verified both JAMS SHA256 identities and audited all
105/57 notes in exact source frames. For each annotated end, it required the
last 250 ms of that note and the next two 250-ms windows to contain no other
annotated note. The comp excerpt has zero qualifying events; the solo excerpt
has two. The two-recording route stopped before window selection, listening
or scoring because both excerpts also share BN1 musical material. Annotation
geometry does not establish acoustic audibility. No inference candidate or
task credit follows from this inventory. A later recorded packet needs a
prospectively chosen player/material split and direct listening labels.

## Independent NSynth train reference accepted — 2026-09-23

The [source-separated packet](PHRASE-EVALUATION.md#nsynth-train-source-separated-packet)
has passed its frozen metadata gate on a distinct NSynth instrument partition.
Pascal verified the 23.8 GB JSON/WAV archive against its source-object MD5,
recorded SHA256, extracted only the 201 MB JSON and four selected WAVs, and
checked all four WAV hashes and full PCM geometry. The locked selection has
two `long_release` instruments (flute and guitar) and two `fast_decay`
instruments (bass and brass), with no overlap with the exposed test groups.
All four train groups have the reserved `independent_evaluation` role. Eight
exact-window, unchanged-gain repeated listening aids are ready under ignored
`build/presence-independent-train/listening-aids/`; the user's numbered review
labels five windows audible and three not audible. The flute late tail (#7) was
not audible despite nonzero PCM; the guitar late tail (#10) was audible but
quiet. The maintained Pascal checker has reproduced a pending-role packet
on stable checked Win32/Win64 without changing its prior reviewed development
output; both targets agree on the new and old packet hashes. It then bound the
eight labels on both targets to the same reviewed packet SHA256
`abbf3b4b3d4243498e99f2b677406292008893961cbc17649744aa6c2f675b19`
with zero unfreed blocks. The input review TSV SHA256 is
`46a722f3817d21ff680ae54dbe2debeff056b4e078f41740047b700c11866ba7`.
The fixed Pascal activity consumer then passed source-free controls and made
one independent eight-window pass without tuning. Checked Win32/Win64 outputs
were byte-identical, SHA256
`0062fedae4de606fd0073c49ac372106eddce271cfeb2e948a8ccf1eecf984dd`,
with zero unfreed blocks. Seven decisions matched. The flute late tail (#7)
was `activity_present` despite the listener's `not_audible` label; its RMS
was 0.000999 and all four activity features fired. Quiet audible guitar #10
remained present; both exact-zero rest windows were silent. The 0.0001 RMS floor
was not retuned. The bounded reference task
[NS-3_notes_04](TODO/DONE/NS-3_notes_04.md) now passes all criteria and earns
1 NS-3 goal point / 0.25 overall point, taking NS-3 to 41% and total completion
to 68.65%. [NS-3_notes_02](TODO/NS-3_notes_02.md) is unblocked and owns the
false-active case, retained quiet-note protections and recorded boundary gates.
No recorded-phrase or noise-robust accuracy follows from this synthetic packet.

## Note-presence exact-window review — 2026-09-23

The user's numbered mobile review resolved the original-versus-late-aid
ambiguity. The original fast-decay guitar sounded like a strum (#1), and the
original mallet had one initial strike (#3); neither whole-clip comment labels
an unreviewed window. The exact repeated late aids for those notes had no
audible sound (#2 and #4). The frozen packet now has six `audible` continuation
or post-control tail windows and two human-reviewed `not_audible` distant
rests. Checked stable FPC 3.2.2 Win32/Win64 Pascal replay agrees byte for byte
(reviewed-packet SHA256
`ab2ee369964d23d88c26f3c4a6cf0f8cefb2908f513efb9d800fdb8c4d337a6b`),
with zero unfreed blocks. Criterion 2 of
[NS-3_notes_04](TODO/DONE/NS-3_notes_04.md) closes at the declared synthetic
single-note scope; unsupported attack, short, quiet, repeated, phrase-gap and
overlap cases remain recorded. The acoustic end of the long-release notes
remains unknown. At that review-only checkpoint, criteria 3 and 4 still needed
a source-role consumer and a presence decision separate from pitch identity.
No task credit was earned.

The fixed Pascal [activity consumer](../tools/pythian.presence.decision.lpr)
then passed digital-zero, subfloor and above-floor source-free controls and
made one eight-window development pass with existing analysis/activity
defaults. Its six activity-present and two no-activity decisions matched the
reviewed labels without using pitch or reading labels before decision. Checked
FPC 3.2.2 Win32/Win64 results matched byte for byte (SHA256
`3a707b395fdd354cf8a9c9fada3a407d27866661551ea2a740f772bc31b2c97c`),
with zero unfreed blocks. This closes criterion 4 only as a packet-consumer
demonstration, with exact-zero negatives and no independent accuracy claim.

The first independent-source attempt stopped before audio. An official NSynth
valid archive was verified (1,068,767,009 bytes, MD5
`87e94a00a19b6dbc99cf6d4c0c0cae87`, SHA256
`00dea2645fbe0069258567da30807a90825e0bab54c077d6481f253096c4e2a0`);
the checked Pascal metadata selector found only one eligible long-release
instrument against six fast-decay instruments under the frozen two-per-cohort
rule. No valid WAV was extracted, reviewed or scored. Criterion 3 and the task
remain open. The ignored `build/presence-independent/` policy and JSON hash,
plus the [source record](PHRASE-EVALUATION.md#nsynth-note-presence-listening-packet--partial-review--2026-09-22),
retain the failed gate. The 1.07 GB ignored archive was later removed during
local cleanup; the policy, JSON hash and reacquisition path remain recorded.
The next bounded attempt was the distinct NSynth train packet above, using
the same frozen two-positive/two-negative gate. The failed NSynth valid gate
stays stopped; do not
relax it, inspect its audio or rescore development data. A genuinely different
selection policy would need separate evidence-backed review and a fresh
pre-audio freeze.

The ignored review TSV at `build/presence-reference/reviewed-2026-09-23.tsv`
binds all eight labels to the frozen coordinates. The exact late aids are
byte-identical and all-zero in PCM (SHA256
`20eaebffe1816e0ffa6f7f854f5ef4ea80d5349faaf0ce1fec1b713e7fde58fa`).
The [packet evidence](PHRASE-EVALUATION.md#nsynth-note-presence-listening-packet--partial-review--2026-09-22)
records the source scope, review sequence and limitations. The checker fixes
`role=development` for every source group and rejects conflicting roles; no
independent note-presence evaluation source is in this packet.

The official [NSynth source](https://magenta.withgoogle.com/datasets/nsynth),
archive and metadata hashes, selection hash, four WAV identities, instrument
groups, geometry and control timing support criterion 1 of the reference task
at its bounded synthetic-note scope. Pitch/velocity are renderer metadata
paired with separate WAVs; the official three-second hold is a dataset-wide
render control, not a per-note MIDI or physical release trace. Partly heuristic
quality tags remain distinct from acoustic labels. This closes criterion 1;
the numbered listening review closes criterion 2, and the fixed activity
consumer closes criterion 4 at its development scope. Criterion 3 remains open.
No independent inference accuracy or task credit follows.

## Accepted local-key/no-key reference packet — 2026-09-23

The user heard both frozen ten-second recordings in full and reported no
pitched music in either. The [reference record](TONAL.md#reviewed-acoustic-no-key-intervals-and-denominator--2026-09-23)
binds that time-local verdict to exact source bytes, notices, independent
development/evaluation roles and source-frame windows. The maintained Pascal
checker reproduces the reviewed labels and crop samples; the separate Pascal
scorer partitions each 441,000-frame no-key window and counts false key
admission apart from tonal, conflict and change coverage. Authored controls
exercise the denominator, not an estimator. Fresh focused QA on stable checked
FPC 3.2.2 Win32/Win64 reproduced exact checker/scorer hashes, retained tonal
controls, rejected unreviewed and wrong-source inputs and reported zero
unfreed blocks. All six criteria of [NS-3_context_03](TODO/DONE/NS-3_context_03.md)
pass. It moved to DONE: +1 NS-3 / +0.25 overall, giving **40% NS-3,
68.40% overall, 36 open / 18 DONE**. The accepted packet unblocks
[NS-3_context_01](TODO/NS-3_context_01.md), which still owns key-decision
thresholds, unknown coverage and independent inference-accuracy acceptance.
Return to that bounded core task under the task-flow selection rule; keep the
three personal style tests separate from core admission.

## Prospective local-key gate and scorer coverage — 2026-09-23

With the reference packet accepted, [NS-3_context_01](TODO/NS-3_context_01.md)
now has a fixed development/evaluation policy for criterion 1. The
[admission gates](TONAL.md#prospective-local-key-admission-gates--2026-09-23)
name all four original recording windows, both reviewed acoustic no-key clips,
supported major/minor cases, excluded coverage and groupwise key, unknown,
change and false-transition limits before independent candidate inference.
The maintained Pascal scorer reports admitted supported frames and false
known-key transitions inside continuous stable reference interiors under a
new scoring-policy identity. Checked stable FPC 3.2.2 Win32/Win64 controls pass;
the all-unknown D911-02 development control gives zero admitted supported
frames and identical score bytes on both targets. Focused QA passed criterion
1's policy and scorer checks, including the symmetric exact one-second edge
control.
Its first pass caught an exact right-edge transition exclusion; the scorer
was repaired before any candidate inference. Fresh checked runs on both targets
pass with zero leaks, and the all-unknown D911-02 replay reproduces the recorded
score hash. Criterion 1 is met; criteria 2, 3 and 5 remain open. No candidate
inference, accuracy result or task credit is claimed.
This batch changes the former stopped variant search into a frozen decision
gate; it has not run a key estimator, closed inference criteria or earned task
credit. Stop policy edits after QA. Next, develop one source-aware Pascal
candidate against the development groups, with retained alternatives and
unknowns; open independent candidate scoring only after the development
gates pass. Do not use the three personal style mixes as key truth.

## Original 22,050-Hz WAV inference preparation — 2026-09-23

The accepted Pascal inference job's source-identity allowlist omitted the
22,050-Hz rate of the exact HU33 reference WAVs. Ticket Guy extended that
identity gate without changing the native resampler or accepting a new codec.
His focused Pascal test generates a one-second mono PCM16 WAV, verifies its
original hash/rate/frame identity and compares whole-run, repeat-run and two
adjacent scope windows and observations byte for byte on the 16-kHz analysis
clock. Checked stable FPC 3.2.2 Win32 passed. The primary agent located the
stable Win64 cross compiler at `fpc/bin/i386-win32/ppcrossx64.exe`; the same
test passed there with zero unfreed blocks. Independent focused QA reran both
targets sequentially and confirmed exact 50-observation halves, completed
scopes, byte-identical adjacent windows/observations, and rejection of
22,051 Hz. This enables exact-source native observation for the selected
recordings but does not establish a key or note decision; criteria 2, 3 and 5
remain open and no task credit moves.

## Cross-part register attribution stop — 2026-09-23

The [frozen Pascal cross-part screen](PHRASE-EVALUATION.md#cross-part-register-peak-attribution-screen--2026-09-23)
compared all saved flute half-frequency gap peaks with the simultaneously
recorded violin's raw note annotations and same-window WAV bins. Among the 11
reference-upper-correct flute events, only 19/222 peaks matched a violin note
covering the full window; two previously highlighted events had 0/25 and
1/20 matches. Baseline-correct controls had 141/904. Hash-bound checked Win32
replay passed twice, byte-identically, with zero leaks. The annotation does
not explain most half-related peaks, while causal source ownership remains
unknown. Stop this route without a blind octave rule or task credit. Further
register admission requires independent source ownership and prospective
ambiguity/coverage evidence; the protected phrase split stays untouched.

## Style-card progress checkpoint and core prerequisite — 2026-09-23

Since focused packet QA closed criterion 4, the private 2026-09-23 three-anchor
source-correspondence screen and the native groove control are two consecutive
[NS-5_evaluation_01](TODO/NS-5_evaluation_01.md) style-card batches that close
no remaining criterion. The former could not authenticate a recording
edition; the latter proves only onset occupancy. Reference-grounded provider
values, annotations and complete six-dimension controls remain missing. Stop
the generic-control sequence and follow the reusable-core dependency path
through [NS-3_context_03](TODO/DONE/NS-3_context_03.md): two exact ten-second no-key
candidate windows are source-bound and ready for time-local human review.
At this checkpoint the review request was pending; no label, context admission,
style acceptance or credit was inferred. Return to the personal style cards when
source-bound musical annotations can ground their remaining criteria.

## Native groove-control slice — 2026-09-23

The [source-independent rhythm fixture](STYLE-CARDS.md#native-rhythm-admission-control-slice--2026-09-23)
exercises the maintained Pascal onset-grid admission contract. Sixteen
authored events on a frozen 64-cell scope all admit; alternating 5-ms jitter
preserves occupancy, while moving one event by one cell changes it without
changing admission count. The exact result replays under checked stable Win32.
This is a narrow reusable comparator control, not a verified style reference
or the full groove trait: role, accent, microtiming and inter-bar relationships
remain unsupported. [NS-5_evaluation_01](TODO/NS-5_evaluation_01.md) remains
open with no credit. Private user-selected mixes were not used.

## Saved register-spectrum gap screen — 2026-09-23

The [Pascal-only gap-peak screen](PHRASE-EVALUATION.md#saved-gap-peak-attribution-screen--2026-09-23)
reused unchanged source-bound flute/violin spectra and separated very-low
recording peaks from octave-related half-integer peaks. In reference-defined
development cohorts, the latter's event-mean single-bin share is 0.026575377
for 11 upper-correct flute events versus 0.000326272 for 85 baseline-correct
events. Four violin spiccato rows average 0.000391648. Checked native controls,
hash bindings, two byte-identical runs and zero-leak reports pass. This is a
descriptive physical contrast only; source ownership, blind register accuracy,
safe ambiguity and low/quiet/short protection remain unproven. The note task
stays open with no credit. Stop this diagnostic sequence until independent
register evidence can support a prospective source-separated decision gate.

## Register model source screen — 2026-09-23

The [HarmoF0 source screen](PHRASE-EVALUATION.md#harmof0-source-feasibility-screen--2026-09-23)
found an author-published compact harmonic model and reported in-domain
frame-pitch accuracy. Its score is not Pythian's admitted-note precision, and
the published evidence does not establish flute register, safe unknowns or
false-rest behavior on the source-separated challenge. The earlier Pascal PESTO
prescreen failed its frozen flute gate with high-confidence octave errors.
Stop another model-swap port based only on an aggregate paper score. No model
was acquired or executed here; [register](TODO/NS-3_notes_01.md) retains its
prospective independent-evidence and ambiguity requirement. This closes no
task criterion or credit.

## ARTBeaT source-pulse archive audit — 2026-09-23

The [official archive inventory](BEAT-TRACKING.md#publisher-archive-contents-checked--2026-09-23)
resolves the uninspected-archive question left by the beat-candidate task:
25 mixed WAVs have beat-time CSV/MIDI annotations, with no listed stems or
source-event files. The MIDI is beat ground truth, not the separate arpeggio or
drum performance. This cannot adjudicate missing 02/04 source pulses, so the
frozen [candidate task](TODO/NS-3_tempo_04.md) remains open and its archive
route is stopped. No new fit, rescore, task credit or percentage change follows.

## Accepted combined synthesis quality — 2026-09-23

The user heard both complete hash-bound combined review clips and answered
“They sound okay” to the targeted 11-second attack/layer/ending and 30-second
held-note/melody-continuity/balance questions. Their earlier coherent-preview
and planned-slowdown observations remain scoped to those clips. No combined
defect or fault time was reported. The [FUND-QUALITY union record](SYNTHESIS-QUALITY.md#fund-quality-bounded-acceptance--2026-09-23)
binds the native and listening-copy identities, disclosed 3.2-second tempo
change and 15-second edit, unchanged replay and protected-prefix evidence,
headroom, MIDI/timing, duration, work bounds and final tail. No repair or new
render is needed for this declared scope. Move
[NS-2_synthesis-quality_03](TODO/DONE/NS-2_synthesis-quality_03.md) to DONE:
+6 NS-2 / +1.50 overall. NS-2 is **100%**, overall **68.15%**, with **37 open /
17 DONE** and **18 active outcomes**. This is bounded synthesis acceptance;
recorded musical learning and the three personal style tests retain their own
gates. Continue with a ready core learning prerequisite under
[task flow](TASKFLOW.MD), especially the unresolved WAV timing/context/note
evidence, rather than reopening accepted listening examples.

## Accepted source and articulation quality — 2026-09-23

The user heard all four complete hash-bound measured-profile packets at native
8/48-kHz rates and said they all sounded good. The packet prompt named clicks,
rough pitch changes, unwanted noise and cut-off endings; no fault time was
reported. Together with the earlier full-window "both sound okay" verdict for
the five-second source-family demo and 6.3-second authored sample loop, the
smooth isolated profile and coherent 30-second paired preview, this covers the
declared source families at explicit listening settings. No source defect was
demonstrated; no core fix or new synthesis render follows.

The [acceptance record](TODO/DONE/NS-2_synthesis-quality_01.md) links the
finite matrix, checked input/output identities, numerical source references,
sample-loop boundaries, exact replay and supported limits. Audible approval is
limited to the reviewed clips and 8/48-kHz measured endpoints; intermediate
rates and interpolation variants retain numerical evidence without distinct
listener approval. All five task criteria pass at that scope. Move the task to
DONE: +8 NS-2 points / +2.00 overall; NS-2 is **94%**, overall **66.65%**,
with **38 open / 16 DONE**. The source task's nonclosing-batch count ends at
acceptance. Its completion unblocks [combined synthesis and streamed listening](TODO/DONE/NS-2_synthesis-quality_03.md);
that task's own interaction and tail verdicts remain open. The next bounded
batch reuses the hash-bound 11-second mix and 30-second paired preview for a
targeted review of attacks, overlapping layers, uninterrupted holds, melody
continuity and final tail. The planned 3.2-second slowdown and 15-second preview
edit are stated in the prompt. Stop new combined renders; if no defect is
reported, audit existing replay and committed-prefix evidence and publish the
union acceptance record. If a defect is reported, repair that exact path.

## Accepted processing and routing quality — 2026-09-23

The user confirmed the finite processing packet was heard through stereo
speakers. Their broad "sounds good" review therefore covers the declared
spectral, modulated-delay, reverb and bus WAVs as stereo playback, including
their presented tails and routing transitions. It does not supply a separate
spatial-motion description or fault timestamps. The lower-pitched FM/PM demo
also sounded good; the high-carrier alias stress file remains a numerical gate.
The only reported fault, excessive 3–6-second demo vibrato, was repaired by the
authored +/-15-cent setting and preferred in the bound before/after review.

The [matrix and scope](SYNTHESIS-QUALITY.md#ns-2-synthesis-quality-02-matrix),
current WAV hashes and existing focused bandwidth, headroom and exact
partition/replay checks satisfy all five criteria of
[NS-2_synthesis-quality_02](TODO/DONE/NS-2_synthesis-quality_02.md) without a
new core algorithm change or redundant suite. Move it to DONE: +6 NS-2 points,
+1.50 overall; NS-2 is **86%**, overall **64.65%**, with **39 open / 15 DONE**.
The processing task's nonclosing-batch count ends at acceptance. Next bounded
core action at that checkpoint: return to the open [source/articulation quality task](TODO/DONE/NS-2_synthesis-quality_01.md)
using its existing finite audition matrix; combined-path task 03 remains blocked
until that source task is accepted.

## Source-family listening packet — 2026-09-23

For [NS-2 source/articulation quality](TODO/DONE/NS-2_synthesis-quality_01.md),
the first matrix criterion was already closed. The next criterion needs actual
family-specific observations and fault times. The user's earlier brass/guitar/
mallet descriptions belong to the recorded NSynth note-presence reference,
not Pythian synthesis output. The existing five-second `sources.wav` and
6.3-second stable sample-loop demo are now hash-bound in the [source matrix](SYNTHESIS-QUALITY.md#finite-listening-matrix--ns-2_synthesis-quality_01)
and supplied for one concise family/loop review. The user heard both full clips
and said they sounded okay, with no fault time reported. This advances the
reassessed review path without a core rerender or quality credit. This is one
nonclosing source batch after that reassessment.

The next bounded source deliverable is a [four-file measured range packet](SYNTHESIS-QUALITY.md#measured-profile-range-listening-packet--2026-09-23)
at native 8/48-kHz rates: three stationary/glide profiles and three
short/long-gate envelope examples at each endpoint. An ignored Pascal packer
uses one uniform 12-times listening gain, preserves source segment identities
and rejects clipping. Stable FPC 3.2.2 Win32 compilation and peak/hash checks
pass. It is a review aid, not a change to the native renderer or its acceptance
range. Criterion 2 and source-task credit remain open until an actual verdict;
stop new copies and resolve only demonstrated faults. This packet is the next
action from the reassessment, not a new diagnostic branch.

## Lower-pitched modulation verdict — 2026-09-23

The user heard the complete existing 7.5-second
[modulation demo](MODULATION.md#earlier-additivefm-checkpoint) and said it was
much better than the high-pitch stress file and believed it sounded good. Its
last two 1.5-second sections are FM and PM at lower carriers. This is a positive
broad sound-quality verdict without a claim about the high-carrier folded band's
audibility. The original numerical alias gate remains valid. No new render or
core change was needed for this clarified listening question; the later stereo
playback answer and evidence audit completed the processing task above.

## Finite processing-packet listener response — 2026-09-23

The user described the presented spectral, delay, reverb and bus examples as
good overall, but found the high-pitched `measured-comparison.wav` unclear as
a listening task. The [source-bound record](SYNTHESIS-QUALITY.md#ns-2-synthesis-quality-02-matrix)
retains the packet identities and limits. This supports broad acceptability of
those examples, without per-case fault times or an explicit stereo-channel
verdict. The FM/PM clip is a deliberate 4-kHz-carrier folded-band stress test,
not a musical demo. Its numerical gate passes, while its perceptual comparison
remains uncertain. The already rendered lower-pitched modulation demo is the
next bounded sound-quality check; its 4.5–6-second FM and 6–7.5-second PM
sections have been supplied for listening. No new render, inference path or
quality-task credit follows from the broad response alone.

## Processing listening checkpoint and reassessment — 2026-09-23

The user heard the entire six-second, hash-bound filtering/dynamics comparison
and said "effects sounds good." The [matrix record](SYNTHESIS-QUALITY.md#ns-2-synthesis-quality-02-matrix)
binds the original and processed three-second phrases. This is favorable for
that fixed setting, without a distinct tail, stereo or routing verdict. The
vibrato A/B preference and this effects check are two consecutive nonclosing
processing-listening batches after the source-family reassessment. Change the
next action from serial single-case prompts to one bounded review of the
existing FM/PM, spectral-motion, delay, reverb and bus WAVs. Seek broad verdicts
and rough times only for faults; do not make new comparison copies or infer
approval from silence. Criterion 2 and task credit remain open until the
remaining supported cases and any demonstrated defects are resolved.

## Control-curve vibrato listener preference — 2026-09-23

The user reviewed the existing 12-second control comparison as good overall,
but judged the vibrato pitch wobble in seconds 3–6 too wide. The existing demo
used a 5-Hz sine at +/-30 cents. Its maintained Pascal authored setting now
uses +/-15 cents with the same period; the native automation implementation
is unchanged. The [before/after evidence](MODULATION.md#listener-directed-vibrato-narrowing--2026-09-23)
binds the two WAV identities, checked stable/development Win32 renders and a
Pascal PCM comparison: 136610 samples changed only in the target section,
none elsewhere, with 0.124268 revised peak. The user heard the bound pair and
said the revised version "seems better on the after." The standard stable demo
WAV was regenerated to the revised hash, and the original is preserved. This
selects the preferred authored setting for one audition; effect and routing
verdicts remain open. This batch closes no quality criterion or task credit.

## Beat source-pulse evidence stop — 2026-09-23

An independent [publisher inventory](BEAT-TRACKING.md#publisher-source-pulse-inventory--2026-09-23)
for ARTBeaT 02/04 found whole-mix beat annotations and musical descriptions,
but no listed source-separated pulse labels, stems or score/events. The archive
contents were not inspected, so the record does not claim the data are absent.
Together with the failed shared-waveform subtraction, this is two consecutive
nonclosing source-evidence batches after the tempo_04 omission reassessment.
Stop 02/04 fit/retention experiments until an independently attributable pulse
reference can be aligned to the exact original WAV clock. Preserve the frozen
candidate gates, prior reports and task credit. Continue the ready NS-2 quality
review; its control-demo vibrato preference is recorded above, while the other
source and processing cases remain open.

## Isolated source review and task-flow reassessment — 2026-09-23

The user heard the [hash-bound measured-profile-1 48-kHz listening copy](SYNTHESIS-QUALITY.md#first-isolated-source-listening-copy--2026-09-23)
and described its complete 6.72-second, seven-key/three-velocity sequence as
smooth. This is a favorable first source-family impression, without individual
timestamps or explicit judgments for aliasing, glides, other profiles/rates,
long/short envelopes or sample-loop exits. No defect is demonstrated by this
comment, and no source-quality criterion or credit closes.

The earlier combined-passage listening/copy batch and this isolated-family
verdict are two consecutive nonclosing NS-2 listening batches. They established
an intentional tempo change and one smooth measured profile, but did not supply
the per-family judgments, defect disposition or operating ranges required by
[NS-2 source/articulation quality](TODO/DONE/NS-2_synthesis-quality_01.md).
Reassessment changes the next action from making preview copies to finishing a
bounded review of the existing finite matrix. Start with its already rendered
12-second oscillator/automation comparison, SHA-256
`801b0a6af642307c3b71bb6423f7cb9323a8c9f4302582d155552d5d3d651ee9`,
then gather the remaining source-specific cases without inventing approvals or
re-rendering unchanged material. Repairs follow only demonstrated defects.

## Combined-source listener observation — 2026-09-23

The user heard the exact 11-second mixed-source listening copy and reported
that its timing seemed to slow in the middle, while the passage resembled
music. The [source-bound listening record](SYNTHESIS-QUALITY.md#eleven-second-combined-listener-checkpoint--2026-09-23)
maps the perceived change to the authored 120-to-96-BPM switch at 3.2 seconds;
the checked native placement and unchanged copy identity support that reading.
No unexpected timing defect is demonstrated. The comment is a broad positive
impression, not family-specific or attack/release/tail approval. NS-2 listening,
defect disposition and union acceptance remain open; no task or milestone credit
changes. Next use the existing finite isolated-source matrix for a bounded
family review, preserving the user's 30-second coherent-preview verdict as a
separate observation. Its first review aid is the existing profile-1 stationary
case at 48 kHz, copied at uniform 12-times gain with unchanged 322560-frame
duration and a checked 0.409424 peak. Exact source/output identities and open
coverage are in the [source-family record](SYNTHESIS-QUALITY.md#first-isolated-source-listening-copy--2026-09-23).
This is one nonclosing NS-2 listening batch after the combined coverage and
numerical-plan criteria closed: it resolves the apparent tempo-change question
and prepares an isolated family review, but supplies no attack/release or
per-family verdict. Stop making listening-gain copies unless a concrete
review need appears; obtain the source-family judgment on this existing copy.

## Combined listening coverage checkpoint — 2026-09-23

The [finite interaction review](SYNTHESIS-QUALITY.md#combined-interaction-coverage-review--2026-09-23)
binds the native 11-second simultaneous-source/tempo/bus passage, complete
88-note sustained layered performance and fixed processing cases to the combined
supported scope. It distinguishes the 3×/44.1-kHz 11-second listening copy and
the 12×/cut-faded 30-second preview from their native synthesis; all cited local
WAV hashes match. This closes [NS-2_synthesis-quality_03](TODO/DONE/NS-2_synthesis-quality_03.md)
criterion 1 without another render, resetting the nonclosing-batch count.
Actual timestamped listening, any demonstrated repair and union acceptance
remain open, with no task or milestone credit.

## Synthesis numerical plan checkpoint — 2026-09-23

The current checked Win32 Pascal [combined plan review](SYNTHESIS-QUALITY.md#combined-numerical-plan-review--2026-09-23)
reconfirms exact 40-note WAV timing and 1/257/4096-frame replay, 11-second
duration, headroom, final tail and corrected 11656 reserved work. The separate
saved 88-note plan retains its exact MIDI gates and bytes through stream replay
and a timbre edit, with 729281 WAV frames, 12 peak voices and 795 peak frame-work
units. This closes [NS-2_synthesis-quality_03](TODO/DONE/NS-2_synthesis-quality_03.md)
criterion 4 and resets the nonclosing-batch count. It earns no task credit:
family-specific and combined audible verdicts, defect disposition and union
acceptance remain open. The user's coherent verdict belongs to the 30-second
preview; the 11-second mixed-source review is still pending.

## Whole-array capacity boundary — 2026-09-23

The checked FPC 3.2.2 Win32 `pythian.learn` rejected the existing full prepared
WAV-C (527081868 bytes, 131770456 stereo frames) with exit 1 and `WAVE source
file exceeds learner size envelope`. Its 256000044-byte file preflight ran
before frame decoding or complete-clip allocation; the fresh output prefix
received no artifacts. The source also exceeds the later 64000000-scalar sample
limit, which this run did not exercise. [CORPUS-SCALE](CORPUS-SCALE.md#missing-admission-and-capacity-boundaries)
records the exact boundary. This is one nonclosing scale batch: it confirms
explicit rejection, while training/model capacity and the multi-recording
semantic workload remain open. Stop repeating whole-array rejection probes;
follow the [admitted-note learner prerequisite](TODO/NS-3_notes_03.md).
The user's coherent listening verdict is for the 30-second synthesis preview;
the separate 11-second mixed-source verdict remains pending.

## Beat-candidate deliverable split — 2026-09-23

Two consecutive metrical experiments for [NS-3_tempo_01](TODO/NS-3_tempo_01.md)
closed no criterion. Source-accent evidence improved some cases but failed the
frozen authored polyphonic/changing-clock gate. Accent parity then damaged
polyrhythm, doubling and the polyphonic case. Both stopped verdicts remain in
[beat tracking](BEAT-TRACKING.md); another selection-factor variant is not the
next action. The earlier candidate-survival audit found a distinct blocker:
the reference-compatible arpeggio phase reached diagnostic rank 13 after
fitting, outside the retained eight-slot pool. Other wrong selections already
had a correct-rate candidate in the pool. Candidate availability and musical
selection therefore have separate, measurable failure modes.

[NS-3_tempo_04](TODO/NS-3_tempo_04.md) now owns the original first criterion's
automatic WAV candidate observations, retained half/double-time and competing
phase alternatives, source-bound candidate-path/clock delivery, and explicit
fitting/suppression/capacity omission accounting. It gets 2 of tempo_01's
original 5 unearned NS-3 points. Tempo_01 keeps 3 points and the first
criterion's *selection* obligation; its original development accuracy,
uncertainty, fast-beat/regression and shared-validation criteria remain there.
Neither task gets credit from the split. The catalog now has 39 open tasks and
14 DONE; NS-3 still has 15.25 overall points open, and total credited progress
remains 63.15%.

The first bounded batch advanced tempo_04's challenge and omission-accounting
criteria. It froze annotated development windows, source groups, candidate
identity, eligibility, 30-ms recall and finite work/coverage gates before
scoring. The intended deliverable is a source-bound candidate-only packet and a
maintained Pascal pool path; it closes only when the declared authored and
source-separated recorded controls show retained alternatives through save and
replay, with capacity/fitting losses distinguished. Stop if the challenge lacks
independent annotations or candidate identity cannot be preserved within the
bounded pool; revise the evidence design instead of tuning a selection penalty.

The [candidate-only protocol](BEAT-TRACKING.md#bounded-candidate-qualification-protocol--2026-09-23)
now freezes six exact WAV/annotation identities, recording-disjoint roles,
windows, candidate support/matching and work/coverage limits before a new pool
run. Local file hashes and maintained default geometry/work constants match
the specification, closing tempo_04 criterion 1 by focused specification QA.
No new retention policy had been scored at this freeze, and no credit changed.

That checker and the first current-policy baseline now exist. Six reports were
saved from original WAVs before the reference scorer ran; all use Pascal-owned
onset/grid/path inference. The checker binds source and annotation hashes,
validates policy/geometry and replays selected paths before comparing candidate
availability at 30 ms. The 02 arpeggio has compatible candidates in 12/17
eligible windows against a 90% gate; 04 polyrhythm has 8/14 against an 80%
gate. The recorded challenge therefore fails. Other rows are challenge
01 9/10 and 03 18/18, and development 05 7/9 and 19 13/14. Crucially,
current 02 window 16 retains and selects a 2/2 matching candidate at index 2;
the historical rank-13 loss belongs to an older isolated policy. The [full evidence and
limits](BEAT-TRACKING.md#first-current-policy-candidate-baseline) name every
failed window. Native Win32/Win64 authored controls, checker compilation,
source/path replay, same-target and cross-target score identity, and negative
identity/policy checks passed. No pool policy changed, no additional criterion
closed and no task credit was earned; this is the first nonclosing batch since the
protocol criterion. The subsequent trace and reassessment are recorded below.

## Beat-candidate omission reassessment — 2026-09-23

The second bounded [tempo_04](TODO/NS-3_tempo_04.md) batch replayed all six
saved candidate reports through an optional Pascal trial-stage trace. Every
saved pool and aggregate fit-work count matched. The 11 failed eligible 02/04
windows split into four with no compatible positive fit, four where compatible
proposals fail the local-peak gate, one suppressed by a selected proposal and
two lost at pool capacity. Admitted observations near annotated beats and
other owner-interval onsets are reported separately. The latter may be valid
musical subdivisions; missing admitted observations do not prove an acoustic
source pulse is absent. The [full per-window record and limitations](BEAT-TRACKING.md#current-policy-omission-stage-trace)
retain that distinction. Normal Win32 inference reports for 02/04 are
byte-identical to their pre-trace versions; checked Win32/Win64 beat and
tracker tests and trace-stage comparisons pass.

Both post-freeze batches closed no additional acceptance criterion: first the
frozen coverage gates failed (02 12/17, 04 8/14); now the trace explains why
pool enlargement alone cannot clear them, but it does not resolve source-pulse
status or the no-compatible-fit cases. Stop this investigation sequence at the
two-batch checkpoint. No task credit or percentage changes. The next active
core action follows the ready [NS-2 source/articulation quality](TODO/DONE/NS-2_synthesis-quality_01.md)
review using its existing finite listening packet and confirmed 30-second
preview verdict. The user's separate NSynth comments describe reference
recordings and are not defects in Pythian's synthesis. Tempo_04 resumes only
with an independently reviewable
source-pulse distinction and a predeclared fit/retention decision capable of
meeting the unchanged gates within their work limit; another candidate-count
walk is not that decision.

One later source-evidence batch tested whether the ARTBeaT publisher's
"same arpeggio" description meant a subtractable shared audio stem in 02/03/04.
The [frozen Pascal screen](BEAT-TRACKING.md#shared-arpeggio-source-isolation-screen-stopped--2026-09-23)
bound the original WAVs and fixed intro, lag, gain and residual limits before
comparison. Both 02-to-03 and 02-to-04 fits failed widely (normalized
residuals .983200/.990077 against <=.001). Stop that subtraction path;
semantic similarity does not supply an isolated source waveform or pulse
label. This is one nonclosing batch after the tempo_04 reassessment. The
unchanged candidate gates, source-pulse review and fit/retention decision
remain open; no task credit changes.

## Core-quality reassessment — 2026-09-23

Two consecutive bounded batches closed no acceptance criterion. First, the
NS-5_scale_02 journal-publication batch protected accepted output prefixes and
checked exact replay, but left semantic providers, process recovery and the
many-hour workload open. Second, the NS-3_notes_01 native-model feasibility
screen rejected a redundant CREPE port and stopped a SwiftF0 v0.2 port before
execution: its available release does not identify model-training source groups,
so it cannot support the required source-disjoint recorded-note claim. Neither
batch earned task credit. Stop journal variants and model-port investigation at
these evidence boundaries.

Follow the ready core prerequisite [NS-2 source/articulation quality](TODO/DONE/NS-2_synthesis-quality_01.md)
using its existing finite listening packet. The next deliverable is a bounded
artifact-identified, timestamped source-family review, followed by repairs only
for demonstrated defects and their changed-path evidence. Its matrix criterion
is already documented; the listening, defect-disposition and operating-range
criteria remain open. The user confirmed that the coherent verdict refers to
the full, hash-identified 30-second synthesis preview.
The [quality record](SYNTHESIS-QUALITY.md#thirty-second-listener-preview--2026-09-20)
now attaches the favorable whole-piece verdict to that artifact while retaining
the separate source-family listening gates. An 11-second combined-source
audition was supplied for the next broad review; its result is pending.
The [louder listening copy](SYNTHESIS-QUALITY.md#combined-source-listener-copy--2026-09-23)
uses maintained Pascal conversion of that same mix at 3-times gain and 44.1 kHz.
Source/output hashes, output headroom and the four-family entry-time map are
recorded. This prepares the pending user review but closes no further source
quality criterion; separate family cases remain in the finite matrix.

After the source-quality artifact and numerical criteria closed, a distinct
[PESTO checkpoint source screen](TODO/NS-3_notes_01.md)
found a publisher-identified MIR-1K training collection and an exact small
checkpoint, unlike the earlier SwiftF0 candidate. A checked Pascal-only
container reader bound its ZIP/storage layout without model execution or a
third-party runtime. No per-song training manifest was established, so all
MIR-1K material is treated as exposed. The checkpoint is a private candidate
for a bounded Pascal decode/forward control, not a qualified register result or
packaged model. This is one nonclosing note-identity batch after reassessment;
the 11-second synthesis listening and source-family verdicts remain pending.

The next private PESTO batch completed a Pascal-only raw-weight/CQT/forward
probe under a frozen physical-control policy. Four synthetic pitches, including
low, quiet and weak-fundamental cases, met its 50-cent gate, but low/quiet
confidence was not calibrated for admission. Before recorded scoring, the
prescreen fixed two exact URMP work groups, every-twelfth-center selection,
100% selected coverage and a >=98% per-group pitch-precision gate. Its bound
[note-identity record](TODO/NS-3_notes_01.md#dev-notes) reports violin 147/148
correct and flute only 26/36, with ten lower-octave errors. Stop this checkpoint
without model tuning, Spring/held-out evaluation, or a maintained provider.
Physical feasibility does not close recorded precision or the remaining
low/quiet/short and delivery criteria. This failure and the preceding PESTO
source qualification are two consecutive nonclosing note-identity batches;
neither earns credit. Reassessment changes the next action to the ready
[NS-2 source/articulation listening task](TODO/DONE/NS-2_synthesis-quality_01.md):
use its existing finite matrix and artifact identities for timestamped family
verdicts, then repair only demonstrated defects. The user has confirmed the
30-second synthesis preview is coherent; the distinct 11-second mixed-source
verdict remains pending. Note-identity work resumes only with new,
independently justified register evidence and a prospective ambiguity/coverage
contract, not a variant of this failed model screen.

## Tonal negative-screen reassessment — 2026-09-23

While the combined-source listening verdict remains pending, one frozen native
[local-key control screen](TONAL.md#authored-tonal-negative-screen--2026-09-23)
ran silence, white noise, a click train, an equal chromatic cluster and a
C-major triad through the unchanged Pascal WAV/chroma/ranker path. Silence
remained unknown; all three non-tonal signals received 24 ranked keys. The
triad ranked C major with gap .015870574, above the largest authored negative
gap .000403354. The declared decision is recorded evaluation required, not an
automatic key threshold. Original Schubert annotation gaps remain unverified
as non-tonal audio, and no held-out composition was opened.

The louder NS-2 listening copy and this key screen are two consecutive batches
since the beat-candidate reassessment without closing an acceptance criterion.
At this task-flow checkpoint, stop additional playback-gain variants and
authored score-gap probes. The next concrete source-quality action is to assess
the already supplied 11-second clip when the listener responds, then route any
specific audible defect to its family. A future local-key admission experiment
requires independent recorded negative/ambiguous references and a prospective
temporal, threshold and coverage policy; the current five controls cannot set
one. No task credit or milestone percentage changes.

## Recorded percussion key screen — 2026-09-23

Following the tonal reassessment, one [frozen source-bound Pascal screen](TONAL.md#percussion-only-recording-screen--2026-09-23)
used a separately described Navy Band drum cadence. The published Ogg identity
matched; external FFmpeg only prepared a WAV. All 24 four-second cells returned
24 ranked keys. The largest top-two gap (.009387836) stayed below the authored
triad gap (.015870574), yielding the predeclared
`broader_recorded_references_required` decision. A percussion-only source
description is not expert no-key annotation for each interval, so this does
not validate an automatic key threshold or false-admission rate. The bounded
Win64 Pascal run reported zero unfreed blocks. The source, policy, probe and
outputs remain ignored under `build/`; no held-out Schubert composition was
opened.

This is one nonclosing batch on the changed recorded-reference path. Stop
source-specific gap testing. The next local-key decision needs multiple
independently verified tonal and no-key/ambiguous intervals plus a prospective
temporal, threshold and coverage rule. NS-3_context_01 criteria 1, 2, 3 and 5
remain open, with no task credit or milestone percentage change. The separate
11-second NS-2 mixed-source listener verdict remains pending; the favorable
coherence verdict applies to the 30-second synthesis preview.

## Local-key reference split — 2026-09-23

The next bounded source qualification used the published
[Freesound Loop Dataset](TONAL.md#loop-level-reference-qualification-stop--2026-09-23).
Its annotation ZIP matched the publisher's checksum; a checked Pascal audit
found 1,472 multiply annotated IDs, including 309 strict unanimous
percussion-only/no-key candidates and 193 strict unanimous non-percussion
major/minor candidates. Four IDs were frozen before audio access. A Pascal
ZIP64 index and raw-deflate extractor fetched their exact WAV entries and
publisher metadata through byte ranges, without downloading the 8.84-GB
archive. All selected entries passed name, size and CRC checks; the tools
reported zero unfreed blocks. The media and exact policy remain ignored under
`build/tonal-loop-reference/`.

The fourth selected loop's uploader filename declares C while its two
researcher annotations agree on D-sharp major. Its license is CC BY-NC 3.0;
the other selected sources are CC BY 3.0 or CC0. The source-quality conflict
stopped the frozen packet before key analysis. Whole-loop researcher labels
also cannot establish local change or ambiguous interval truth, and the
annotators had seen automatic pre-analysis suggestions. No threshold, measured
false-admission rate, local-key criterion or credit follows.

The performed-percussion screen and this stopped qualification are two
consecutive nonclosing local-key batches. The task-flow reassessment splits
an independently useful recorded interval reference packet into
[NS-3_context_03](TODO/DONE/NS-3_context_03.md), ahead of the retained
[NS-3_context_01](TODO/NS-3_context_01.md) inference decision. The original
four unearned NS-3 goal points are redistributed **1+3**; the overall
completion remains 63.15%, with 40 open and 14 DONE tasks. The next deliverable
is exact source/edition and timed-label qualification across positive,
no-key/ambiguous and changing-key recordings, with a Pascal checker and
independent recording-group split. Stop source-specific gap screens until that
packet is qualified. NS-2's 11-second listening verdict remains pending.

## Score-transferred ambiguity intervals — 2026-09-23

The first bounded [context reference](TODO/DONE/NS-3_context_03.md) batch used only
the two existing Winterreise HU33 development compositions. The
[publisher's annotation policy](TONAL.md#score-transferred-ambiguity-check--2026-09-23)
explicitly treats ann2's ambiguous score passages as no-key, with the
score-to-audio regions transferred by alignment and transposition. A frozen
checked Pascal audit bound the two original score CSVs, current WAV/audio CSVs
and preflight JSONs; all five/three ann2 rows paired with one fixed
transposition per composition. It mapped three D911-02 and one D911-16
internal ambiguity gaps to exact source frames and retained every overlapping
ann1/ann3 key. The 594-ms Win64 run reported zero unfreed blocks. No audio
prediction, threshold or other composition was opened.

These are one annotator's *score-transferred ambiguity* intervals, not
independently verified non-tonality or consensus unknown. Leading/trailing
annotation gaps remain unlabelled. This is one nonclosing reference-packet
batch since the split, with no criterion, credit or percentage change. The
next deliverable freezes composition-disjoint development and independent
reference roles, then qualifies exact source/edition and timed labels for
stable keys, changes and no-key/ambiguous behavior. A later checker must
reproduce those identities and coverage denominators before inference scoring.

The second bounded reference batch froze [composition-level roles](TONAL.md#local-key-reference-group-roles--2026-09-23):
Winterreise D911-02/16 are development-exposed; D911-05/19 and all their
performances are reserved independent cases; D911-01 is excluded; remaining
compositions are quarantined. The FSLD annotation index was screened, so none
of its loops is an untouched independent case. Publisher metadata identifies
one additional, separately recorded percussion loop but supplies no timed
acoustic no-key label. No new audio or annotation contents were opened, and no
inference ran. The selected independent recordings, interval packet and Pascal
isolation checker remain unqualified, so this is a second nonclosing batch.
At Athena's two-batch checkpoint, stop source-specific screens. Resume this
task only with a bounded plan that can close a complete packet criterion:
reacquire the reserved composition entries without label-driven selection,
verify edition and timing, and implement the source/role checker before any
independent scoring. The ready NS-2 source-quality listening task remains the
current core prerequisite while the 11-second review is pending.

The next bounded reference batch closed its source/edition and reviewed-interval
criteria using only the already development-exposed D911-02/16 HU33 groups. The
[published packet](TONAL.md#bound-development-local-key-intervals--2026-09-23)
binds the 1933 singer/pianist, archive/notices, all six audio CSV hashes and
both score-ann2 hashes. It retains four transferred ann2 ambiguity spans with
every alternative ann1/3 label, stable major/minor regions and the unanimous
D-minor to D-major D911-16 change at frame 1,761,795. Checked FPC 3.2.2
Win64 Pascal QA verified current source bytes and all 18 table spans against
the prior complete partitions; the score/audio gap audit replayed on current
bytes. Both runs reported zero unfreed blocks. No evaluation composition or
key estimator was opened. NS-3_context_03 criteria 1 and 2 are met; criteria
3–5 and all completion credit remain open. Next build the maintained source/role
checker, qualify the reserved compositions and freeze separate coverage
denominators before any held-out inference score. NS-2's 11-second listener
verdict is still pending.

The first post-qualification batch added a maintained
[Pascal reference checker](TONAL.md#reproducible-pascal-reference-checker).
It binds current development WAV, audio/score CSV and notice bytes, rebuilds
the full source-frame annotation partition and derives ann2's four
score-transferred ambiguity spans. Checked stable Win32/Win64 reports match
each other, the earlier accepted partitions and same-target replay. A damaged
copied notice and an occupied output prefix reject before output. The command
is included in the normal native build. Its Pascal ZIP path verified the
publisher archive, selectively extracted 13 exact entries and reproduced the
same two reports from a fresh asset directory. The independent group and scoring
denominator portions of context_03 remain open, so this is one nonclosing
batch after criteria 1 and 2; no task credit changes.

The next bounded batch acquired exact D911-05/19 HU33 evaluation entries
under a frozen whole-composition policy. A checked Pascal selector verified
the publisher archive and recorded hashes and lengths for the two WAVs,
six audio local-key CSVs, two score-ann2 CSVs, the README and two notices
without reading labels, decoding audio or running inference. The maintained
[Pascal checker](TONAL.md#reserved-evaluation-identities--2026-09-23) now
enforces disjoint composition roles and WAV identities. Stable Win32/Win64
source-free controls and hash verification pass with zero unfreed blocks.
NS-3_context_03 criterion 3 closes. The same HU33 performer chain limits
future scores to unseen compositions within that chain. Evaluation interval
and coordinate reproduction for criterion 4, and separate coverage denominators
for criterion 5, remain open. No task credit or milestone percentage changes;
the nonclosing-batch count resets after this criterion closure.

The following packet batch closed NS-3_context_03 criterion 4 with a
[tracked Pascal evaluation reader](TONAL.md#reserved-interval-coordinate-replay--2026-09-23).
It reconstructs D911-05/19 HU33 original annotation boundaries and full
22,050-Hz source-frame partitions, verifies score-ann2 mode/transposition
and fixed roles, and writes labelled JSON only under ignored `build/`. The
274-second D911-05 WAV required widening the source/time budget from 180 to
360 seconds. Stable checked Win32/Win64 evaluation reports match byte for
byte and report zero unfreed blocks. Replayed development reports remain
identical to the prior accepted bytes. Neither zero score gaps nor uncovered
frames establish expert no-key truth; D911-19's annotator disagreement remains
unresolved. Criterion 5 and the remaining no-key/ambiguous source qualification
need a separate scoring policy and acoustic evidence. No task or milestone
credit changes.

The next reference-qualification batch identified five **fully covered**
audio-local-key annotator conflicts in the exact D911-02 and D911-16 HU33
recordings. The [source-clock table](TONAL.md#audio-annotator-conflict-intervals--2026-09-23)
retains all three labels and half-open frames: 152,145 conflict frames in 02
and 84,231 in 16. A checked Pascal audit matched fresh development reports
byte for byte to the accepted artifacts. These are two distinct
composition-group *ambiguous* references under NS-3_context_03 criteria 1/2;
they are not expert acoustic no-key intervals. With the already published
stable keys and D911-16 unanimous change, criteria 1–4 are met. Criterion 5
still needs separate supported-key, abstention-on-conflict and change
denominators before the task can earn credit. The current packet cannot
support a measured acoustic no-key rate.

The next maintained batch froze separate supported-key, full-coverage
annotator-conflict and agreed-change scoring denominators and implemented a
[Pascal packet scorer](TONAL.md#separate-packet-denominators--2026-09-23).
Checked stable Win32/Win64 controls pass exact, unknown, mistimed and
flickering cases; synthetic all-unknown predictions reconcile all four
source-bound reports, while wrong-source, missing-coverage and unbound-report
inputs reject. No inference ran and no accuracy credit is implied. This
closes NS-3_context_03 criterion 5. A completion audit found that the task
description and downstream NS-3_context_01 still require actual acoustic
non-tonal intervals, absent from the current packet. That requirement is now
explicit as criterion 6, with no new credit or task move. The
[MTG-Jamendo tonal/atonal release](https://github.com/MTG/mtg-jamendo-dataset/blob/master/derived/music-classification-annotations/README.md)
is track-level and cannot by itself close the time-local reference gap.
The next bounded no-key batch froze [two independent source families and fixed
10-second windows](TONAL.md#prospective-acoustic-no-key-screen--2026-09-23)
before audio inspection: an attributed original WAV for development and a
separately authored original Ogg converted externally to WAV for evaluation.
Commons byte lengths/SHA-1 match both originals; a stable FPC 3.2.2 Pascal
checker confirmed both 441,000-frame windows contain the exact decoded source
samples at their frozen coordinates. Time-local listening review is pending;
neither candidate counts as no-key truth, and no false-admission denominator
or inference result is claimed. This is one nonclosing batch after criterion 5.
If review finds music or is uncertain, exclude that fixed window and reassess
the source path before another candidate search. Preserve the accepted
key/conflict/change packet.

The next [maintained no-key checker](TONAL.md#prospective-acoustic-no-key-screen--2026-09-23)
batch bound both original media, conversion and exact review windows through
Pascal. Checked stable Win32/Win64 reports are byte-identical; wrong source or
window rejects with zero leaks. Reports explicitly mark listening labels
pending. Together with the acquisition batch, this is **two consecutive
nonclosing batches** after context_03 criterion 5. Reassessment: the source
and coordinate evidence is sufficient for review, while code or another
unreviewed recording cannot supply the missing acoustic truth. Stop this
source path until the fixed-window verdicts arrive. If both qualify, bind the
verdicts and add a separate non-tonal false-admission denominator in Pascal;
if either does not, exclude that window and redesign the source selection
before reacquisition. Work on other ready core prerequisites in the meantime.

## NS-5 listening-protocol criterion — 2026-09-23

Focused specification QA for [NS-5_evaluation_01](TODO/NS-5_evaluation_01.md)
compared the current [style packet](STYLE-CARDS.md#fixed-execution-and-listening-packet)
with the original [corpus protocol](CORPUS-EVALUATION.md#generation-controls-and-listening-packet).
The three seeds, retained 120-second cases and full-duration scoring, fixed
listening positions, 0..3 rubric, reviewer timestamps and six seed-731 paired
15-second edits agree. Criterion 4 is specified and reviewed; criterion 3 was
already closed. No generation or listening was executed by this doc-only QA.
Style-specific reference traits, quantitative gates and preserving/breaking
controls keep criteria 1, 2 and 5 open. No task credit or milestone percentage
changes. This accepted criterion resets the two-nonclosing-batch checkpoint;
the next work must still address the remaining reference-grounding evidence
or a ready core prerequisite, not repeat protocol wording.

## Private style-source correspondence stop — 2026-09-23

One frozen audio-match batch tested a declared chapter from a user-selected
full mix against a separately artist-published recording. Pascal decoded the
prepared WAVs and scored three interior 20-second envelopes plus a different-
chapter control. Interior scores were 0.825857, 0.887276 and 0.826554, with
inconsistent and nonunique placements; the control was 0.118660. The declared
gate failed before the separately planned waveform confirmation. The repaired
failure exit has zero unfreed blocks on stable FPC 3.2.2 Win32. Exact source
identities, policy, media and results stay under ignored `build/`, consistent
with the user's private-style-input direction.

The chapter is not an independently verified recording/edition or song group;
the failed match does not prove its metadata title false. Stop this candidate
without a threshold or upload sweep. [NS-5_evaluation_01](TODO/NS-5_evaluation_01.md)
criteria 1, 2 and 5 remain open, with no credit. This is one nonclosing batch
since the accepted protocol criterion; follow the ready synthesis-quality
review while a distinct source-grounding path is developed.

## Local-key provenance criterion — 2026-09-23

While synthesis listening remains pending, focused current-source QA closed
[NS-3_context_01](TODO/NS-3_context_01.md) criterion 4. Stable FPC 3.2.2
Win32 core tests confirm exact source-frame regional boundaries, unknown on
silence, safe rejection and musical-time mapping across source offsets and
changing tempo. A saved-profile checker remeasures and binds the exact WAV,
report, candidate ranks and every key/tempo cell. A deliberate caller-selected
rank-18 key survives native save/reload with `explicit_local_region_selection`
provenance; it is not mislabeled as inferred truth. The focused runs exit 0
with zero unfreed blocks. [Detailed identities and limits](WAVE-CONTEXT-ADMISSION.md#source-bound-manual-region-replay--2026-09-23)
are linked from the task; generated evidence is ignored under `build/`.

Automatic key/change admission, confidence, unknown coverage and independent
recorded accuracy remain open under criteria 1, 2, 3 and 5. No task credit or
milestone percentage changes. Closing this criterion resets the consecutive
nonclosing-batch checkpoint; the stopped tonal representation experiments do
not restart.

## Frozen local-key candidate stop and reassessment — 2026-09-23

For [NS-3_context_01](TODO/NS-3_context_01.md) criterion 2, one ignored
development-only Pascal probe froze note-specific sparse-peak support, onset
increments, a two-second context, ranked diatonic fits and explicit unknown
gates before scoring. Its exact policy, source and report hashes, outputs,
ranked evidence, checked Win32/Win64 run logs and gate JSON remain under
`build/localkey-candidate-1/`. The initial source run failed before prediction
or scoring on a tiny negative rolling-sum residue. A direct bounded-sum repair
preserved the formula and passed source-free controls before the only recorded
development runs. Checked runs stayed within 60 seconds and 128 MiB per source
and reported zero leaks. Full output JSON hashes differ across targets; both
produce the same integer tonal scorer counts. This does not establish byte
parity of ranked floating evidence.

The frozen gate reports D911-02 exact 183,015/1,183,203 and admitted
734,706/1,183,203; D911-16 exact 260,190/2,223,522 and admitted
1,098,531/2,223,522. Exact precision is 183,015/734,706 and
260,190/1,098,531 respectively. Conflict unknown is 29,988/152,145 and
39,690/84,231; D911-16 finds 0/1 agreed changes. Both groups exceed the
stable-interior false-transition limit (5/1,006,803 and 4/2,091,222). The
Pascal rain-window projection checked source/window PCM identity and yielded
one unknown segment for the exact reviewed [8,18) seconds; the separate
no-key scorer counts 0/441,000 false-key frames. The combined development
gate exits 2 on both target score sets. [Detailed denominators and limits](TONAL.md#frozen-note-aware-local-key-candidate-stopped--2026-09-23)
remain in the tonal record. D911-05, D911-19 and the independent applause
window were neither inferred nor scored. No inference code was promoted, no
independent accuracy claimed and no credit changed.

The native 22,050-Hz source preparation and this candidate are two consecutive
nonclosing batches after criterion 1's accepted policy. The first removed a
source identity barrier; the second tested and rejected a concrete note-aware
heuristic. The measurements do not distinguish actual notes from harmonic
partials, simultaneous roles or tonic evidence well enough to justify another
ranker/threshold/context variation. Stop this investigation sequence. The
next core result will follow the already frozen
[note-presence reference task](TODO/DONE/NS-3_notes_04.md): obtain exact listener
labels for its existing continuation, post-control and rest windows, then
qualify its source-bound packet or keep it open with the precise remaining
blocker. Local-key inference stays open until a distinct source-grounded
observation and prospective unknown/change gate can be justified. This is a
change of deliverable, not a reset of unsuccessful-attempt evidence.

## Exact-window note-presence listener update — 2026-09-23

After the local-key stop redirected core work to
[NS-3_notes_04](TODO/DONE/NS-3_notes_04.md), the user reviewed the existing
4-second fading guitar clip and marked its pitched sound audible in all three
frozen 250-ms windows: [2.50,2.75), [3.00,3.25) and [3.75,4.00) seconds.
The final label supports an audible post-control tail but does not locate a
silence endpoint beyond the file. Their brass reply said "audible, but sounds
like loud static" without locating a clearly pitched note in its three
windows; both fast-decay late windows are also still pending. The
[packet](PHRASE-EVALUATION.md#nsynth-note-presence-listening-packet--partial-review--2026-09-22)
retains the exact scope. This partial human response closes no acceptance
criterion and earns no credit; complete the five missing window judgments
before publishing a reviewed label TSV or scoring presence. No additional
source-screen or threshold variant is authorized by this response.

For easier exact-window review on mobile, one ignored Pascal playback aid
repeated only the five pending quarter-second source intervals, each four
times with equal digital-silence gaps. Checked stable Win32/Win64 compiles
and runs verified original source hashes, WAV geometry, exact repeated PCM
bytes and cross-target output hashes with zero reported leaks. The two
fast-decay late windows are each 4,000 frames of exact PCM zero; three brass
windows contain nonzero samples but still need a pitch-specific listener
verdict. This is a bounded presentation aid, not changed reference selection
or a substitute human label. It closes no criterion; stop aid variants and
await the five unresolved judgments.

The user's next brass clarification exposed a wording defect in the review
question: asking for a "pitched note" mixes presence with pitch identity.
They hear brass source sound, but describe each attack/hold as unpleasant
old-TV/radio static. The [packet convention](PHRASE-EVALUATION.md#nsynth-note-presence-listening-packet--partial-review--2026-09-22)
now defines `audible` as source sound heard regardless of its pitch or
timbre; `not_audible` and `uncertain` stay distinct. The previously reviewed
guitar pitch also establishes source audibility. No brass window is inferred
from the broad timbre statement, and the eight frozen windows and TSV format
are unchanged. This is a pre-scoring question repair, not a new estimator,
listener label, criterion or credit.

## Journal publication checkpoint — 2026-09-23

For NS-5_scale_02 criterion 2, the acoustic journal commands now stage model,
audition and report files under a reserved sibling directory, require a fresh
prefix and publish the report last. This protects an accepted profile from a
rerun and leaves interruption before report publication visibly incomplete.
The contract and manual cleanup condition are in [ANALYSIS-WAVE](ANALYSIS-WAVE.md#training-from-journals).
A small saved WAV/cache run rejected reuse of an accepted prefix and an occupied
staging directory without changing output bytes. Fresh training from the same
completed cache produced identical JSON/model/WAV with FPC 3.3.1 and 3.2.2
Win32; saved replay reproduced the WAV and a saved blend loaded. The checked
fixture is ignored under `build/`.
The same batch repaired late freshness rejection: all four commands now check
the output prefix before loading inputs, then check again when publishing.
An intentionally missing input confirmed that occupied prefixes and staging
directories reject first, preserving the accepted output hashes.

This was one bounded nonclosing acoustic preparation batch. It does not test
process kill/restart, durable writes, semantic providers, long-workload budgets
or song-boundary admission. No NS-5_scale_02 criterion or credit closes. Stop
publication variations here and follow the ready semantic/core prerequisites;
the user's three selected full mixes remain preference tests, with user review
at substantial listening or design checkpoints.

## Metrical source-evidence checkpoint — 2026-09-23

The ready beat-level prerequisite tested one frozen, Pascal-only alternation
hypothesis after the stopped source-recurrence comparison. All nine cached
development cases and unchanged-method ablations ran with saved predictions
before the independent 30-ms scorer. The authored polyphonic case fell to zero
matches; polyrhythm and doubling regressed materially. Controls and exact
ablation replay passed, so this is a scientific rejection, not an implementation
fix to retune. The selector and scorer ran in Pascal against frozen historical
model outputs; no external runtime was executed, and this does not qualify a
Pascal-native beat provider. [Beat tracking](BEAT-TRACKING.md#accent-parity-stopped) records the
full result and ignored evidence. This is the second nonclosing metrical batch;
stop recurrence/parity variants and reassess the observation model. No beat
provider or task credit changed. The next safe goal work can follow another
ready core prerequisite while independent metrical evidence is developed.

## Full-length private style inputs — 2026-09-22

The user supplied one full multi-hour mix for each initial target style and
identified 30-second excerpts as inadequate for a holistic style judgment.
The three complete audio streams (10.19 hours total) were acquired under ignored
`build/` and converted outside the repository to full-length PCM WAVs. The
one-off converter is preparation only; maintained analysis and inference remain
Pascal-owned. Source-specific identities, links and media remain in the ignored
local manifest, not in the tracked corpus records. The user confirmed the
separate build cleanup succeeded.

These inputs supersede the old excerpt-first direction for current development,
but do not yet establish accepted genre cards or independent evaluation groups.
Checked Pascal jobs completed full source-bound feature caches for all three
recordings. A private Pascal mapper conservatively excluded feature windows
crossing declared chapter cuts; those metadata cuts still need audio review.
Declared chapter counts exceeded the journal learner's former 32-range/profile-source
limit for every mix. The existing [NS-5 scale task](TODO/NS-5_scale_02.md)
owns bounded contribution accounting and song-boundary handling. The later
[range/source checkpoint](#bounded-full-mix-acoustic-learning--2026-09-23)
advances that path. Keep NS-5_evaluation_01 open pending whole-work review and
musical annotations.

## Bounded full-mix acoustic learning — 2026-09-23

The saved acoustic journal path now treats each declared training range as one
WFC sample boundary while bounding physical WAV identities separately. It permits
at most 4096 disjoint ranges, 32 distinct WAV digests and 65536 candidate slots.
The profile loader rejects repeated WAV identity with conflicting cache bytes or
geometry, and the blend path coalesces exact ranges while rejecting partial
overlap. Training, frozen-palette fit and context attachment reuse one verified
WAV/cache handle for repeated references to the same pair. All maintained code
and inference remain Pascal.

Checked FPC 3.2.2 Win32 passed the profile fixture, including 33 ranges from
one physical source, exact-range blend accounting, overlapping/conflicting-cache
rejection and the 33-physical-source cap. A private 33-range CLI run trained,
reloaded, replayed to identical audition bytes, blended, measured palette fit and
attached contexts. Full user-selected development mixes contributed 44, 42 and
68 conservatively mapped chapter ranges, with 126753, 286271 and 159740
observations respectively. The first learned the shared acoustic vocabulary;
the other two used that frozen vocabulary. Saved blends retained 154 distinct
ranges and three physical source identities. A further blend added only the
repeated recording's weight, retaining 154 distinct ranges and 196 weighted
samples. Saved three-source replay verified the explicit WAV bytes and rendered
from the persisted profile without caches or relearning. The first full-mix
training audition and its replay have identical SHA-256 bytes. Exact paths,
identities, commands and audio remain under ignored
`build/`.

This proves bounded acoustic training and mechanical reuse over the selected
full-length inputs. It does not establish verified song cuts, musical traits,
accepted styles, semantic provider learning, interrupted recovery or the full
NS-5 workload budgets. No task completion credit changes. The next scale result
must satisfy the remaining [NS-5_scale_02](TODO/NS-5_scale_02.md) criteria after
its semantic prerequisites; do not use acoustic token counts as musical evidence.

## Core-first re-alignment — 2026-09-23

The user wants the generally reusable synthesis and WAV-learning core built out
first, with their personally selected styles used to test and steer it. Those
preferences are not dependencies of basic core function and do not define the
genres globally. Preserve the existing general correctness, provenance, native
execution and independent-consumer requirements. Seek the user's input when a
substantial playable result or design choice can change direction; routine
timed annotation and engineering checks should not demand frequent listening
responses. The current goal assessment and task credits are unchanged by this
priority clarification. Resume a ready core task while the detailed NS-5 style
card remains open for later source-bound musical evidence.
The next finite core listening checkpoint reuses the already rendered 30-second
[paired synthesis preview](SYNTHESIS-QUALITY.md#thirty-second-listener-preview--2026-09-20),
whose current 44.1-kHz WAV identity and geometry were rechecked with the stable
Pascal inspector. It invites a high-level audible verdict before choosing sound
repairs; it does not stand for the remaining source/effect listening matrix.

## User preference scope and full-mix review — 2026-09-23

The user confirmed that they personally selected all three complete mixes and
that each meets the style they intend. These are preference-scoped test labels,
not a claim to define chillwave, stoner rock or lofi universally. All three are
development-exposed training candidates; none is a held-out evaluation group.
The private review packet and Pascal audit bind the full 48-kHz WAV bytes and
declared chapter maps under ignored `build/`, without publishing source-specific
identities in tracked corpus documents. First/middle/last frames spot-decode and
the full WAV byte hashes are recorded privately. The 16-kHz journals had already
fully decoded their separate analysis derivatives.

The holistic preference judgment resolves source suitability for development,
but no timed context, groove, harmony, role, sound or structure annotation has
been reviewed. Metadata chapter cuts and independent source groups are likewise
unverified. The acquisition/cache batch and this review-packet batch close no
NS-5_evaluation_01 criterion. At the task-flow checkpoint, stop further
metadata-only or level-only source preparation. The next reference deliverable
when that task resumes must bind reviewed musical observations and uncertainty
to exact intervals, then
freeze preference-scoped comparator thresholds before evaluation. No task credit
or milestone percentage changes.

## Pro Sensory chillwave candidate rejected — 2026-09-22

The user listened to the entire 230.365-second, hash-bound
`Chill-Pro-Sensory.wav` and rejected it as a holistic chillwave reference:
the tempo felt off-style and the sound spooky/dreary/ominous. They could not
identify clear beat, bass, lead or section-change times. The
[stopped source record](STYLE-CARDS.md#pro-sensory-isolated-source-rejected--2026-09-22)
retains attribution and exact identity, but it has no chillwave training,
calibration or evaluation role. No BPM, structure or other traits are inferred.

The mood-only first review and this rejection are two consecutive nonclosing
review batches after the source-screen reassessment. Stop the Pro Sensory route.
Finish the existing C-early candidate's recording/cut correspondence and seek
a full-work style verdict, incorporating any user-named exemplars before new
acquisitions. This is a changed deliverable using existing evidence, with
holistic suitability, source identity/quality and six timed trait dimensions
still required. NS-5_evaluation_01 remains open with no completion credit.
The [three original YouTube compilation sources and declared candidate chapters](STYLE-CARDS.md#candidate-reference-cards)
are now explicit. Only 30-second excerpts of those chapters were analyzed;
none supplied a whole-work genre judgment. The user identified this as a likely
weakness in judging genre from the original source candidates. Review each
complete chapter before promoting its tag or short probe into style evidence.

## NSynth listener comments received — 2026-09-22

The user described the four fixed clips: harsh/noisy brass, a strummed fading
long-release guitar, a bell-like fast-decay guitar and an inaudible mallet.
They later confirmed that the brass fades after the documented 3.0-second
note-off, supporting a perceived post-control decay without fixing its endpoint.
These are valuable perceptual observations but specify no 250-ms window around
the documented 3.0-second note-off. The [reference packet](PHRASE-EVALUATION.md#nsynth-note-presence-listening-packet--partial-review--2026-09-22)
now records them as whole-clip comments and preserves all exact-window labels
as pending. A targeted window question is open. The low-level mallet result is
not converted into a universal silence claim; playback level was not reported.
This is the second nonclosing batch on the reassessed reference route. Stop
expanding this packet or screening sources; follow the external blocker until
the fixed windows receive `audible`, `not_audible` or `uncertain` labels. No
NS-3 note-presence criterion, scorer or credit changes. NS-5's separate
chillwave reference listening remains pending.

## PianoVAM source stop and reference reassessment — 2026-09-22

The reassessed NSynth listening packet now has a tracked Pascal checker. It
binds four exact WAV hashes and eight continuation/tail/rest candidate windows,
and rejects a review file with a changed source, window or frame boundary.
At that checkpoint, stable FPC 3.2.2 and trunk FPC 3.3.1 emitted the same
nine-decimal pending-packet SHA256
`b3521259961ca03353cd10472ef0b884eb21ea1f2e825c36f27cd92726beb2a7`;
the original fixed RMS values matched. A synthetic all-uncertain review parses,
and a one-frame alteration fails before packet output. See the
[listening packet and replay](PHRASE-EVALUATION.md#nsynth-note-presence-listening-packet--partial-review--2026-09-22).
The four clips are development-exposed. Listening labels have been requested
and remain pending; no acoustic tail endpoint, scorer or task credit is claimed.
This is one nonclosing deliverable batch after the reassessment below.

The second bounded `NS-3_notes_04` source check stopped before audio acquisition.
The current [PianoVAM v1.1 card](https://huggingface.co/datasets/PianoVAM/PianoVAM_v1/blob/main/README.md)
publishes per-file WAV, MIDI and TSV access, but states that the TSV is derived
from MIDI. Its `key_offset` denotes physical key release; its `frame_offset`
considers sustain pedal. The [authors' paper](https://github.com/alexanderlerch/2025-ISMIR-PianoVAM/blob/main/ISMIR2025_template.tex)
describes adjusting transcription offsets to pedal release. Therefore neither
field independently labels when a recorded tail becomes inaudible. The current
dataset license is CC BY-NC-SA 4.0, limiting reuse in a general library.
No files were acquired or scored, and no credit closes.

Guitar-TECHS and PianoVAM are two consecutive source screens without an
accepted acoustic tail/rest reference. Following the task-flow checkpoint,
stop source shopping and finish the smaller reviewable reference packet from
the four already verified CC BY 4.0 NSynth notes. Freeze the existing 3.0-s
gate, exact listening windows and unknown option before requesting listening
judgments. A listener may confirm continuation, post-gate tail and distant
rest or mark any window uncertain. If those judgments support the packet's
instrument-group scope, finish its Pascal checker and source-separated roles;
recorded phrase transfer and all NS-3_notes_02 scoring remain open. This
reassessment authorizes a concrete review deliverable, not a new estimator.

## Note-presence reference split and P1 source stop — 2026-09-22

At the two-nonclosing-batch checkpoint, the qualified external reference was
split from `NS-3_notes_02` into its true
[NS-3_notes_04 prerequisite](TODO/DONE/NS-3_notes_04.md). The original four NS-3
goal points are redistributed **1 reference + 3 observation/decoder**, with
no new or accepted credit. The catalog has **38 open / 14 DONE** tasks,
52 total; NS-3 stays 39%, NS-5 27%, overall 63.15%.

The first bounded reference screen used the official CC BY 4.0 Guitar-TECHS P1
single-note archive. Pascal verified its length/MD5/SHA256, decoded 142
per-string MIDI notes and both separate WAV captures, then measured four
MIDI-selected post-end/distant-rest contrasts under a rule frozen before
reading audio. None meets the required direct-input **>4** and amp-mic **>2**
tail/rest RMS ratio together; exact per-note results and replay hash are in
[phrase evaluation](PHRASE-EVALUATION.md#guitar-techs-p1-reference-screen-stopped--2026-09-22).
Stop this source route without retuning or opening P2. This is one nonclosing
batch on the split task. The next source check must verify that a published
control-release and a distinct frame/acoustic offset have clear derivation,
compatible licensing and individually accessible raw recordings before
acquisition. Preserve unknown release endpoints and the independent phrase
holdout. No inference or style acceptance changes.

## Known-gate slope rule stopped — 2026-09-22

For `NS-3_notes_02`, a frozen Pascal-only envelope-slope diagnostic measured
the four source-bound NSynth notes without retuning or opening Spring/reserved
phrase material. Both long-release notes fail the required gate-localized score;
both fast-decay notes abstain at the documented 3.0-second note-off. The mallet
has no nonzero PCM sample after frame 19755, long before that gate. Exact scores,
source identities, policy and deterministic CSV hash are in
[phrase evaluation](PHRASE-EVALUATION.md#fixed-gate-slope-diagnostic-rejected--2026-09-22).

Stop the slope rule. This is the second consecutive nonclosing batch under the
changed source approach, so the next batch must follow the task-flow
reassessment. Keep audible activity, latent key/gate status and musical note
boundaries distinct; first obtain separately supported acoustic tail/rest labels
or an equivalent discriminating source before another presence scorer. The
existing low/quiet/short/gap, recorded phrase and independent gates remain.
No NS-3 or NS-5 criterion or credit closes.

## Known-gate release reference — 2026-09-22

The NS-3 note-presence prerequisite changed source after the URMP F0 stop.
The official CC BY 4.0 NSynth JSON/WAV test archive provides a documented
three-second note-off followed by one second of audio. A frozen Pascal selector
chose two `long_release` and two `fast_decay` notes from four distinct
acoustic-labelled instruments; this test partition is development-exposed.
The complete archive matched its published length/MD5, and Pythian's Pascal
reader verified each selected source and measured fixed pre/post-gate spans.
Both long-release notes retain post-gate sound and decay; the fast-decay controls
are near silence by the gate. The contrast shows why energy alone cannot be a
held-note label. [Exact source, WAV and report hashes and levels](PHRASE-EVALUATION.md#fixed-gate-release-controls--2026-09-22)
are bound. Selection and audit replay hashes matched; only four WAVs were
extracted under ignored `build/presence-contrast/`.

This supplies controlled gate/release contrast after the two-batch reassessment.
It does not label every audible tail frame, qualify recorded phrases, or close
`NS-3_notes_02`. The next bounded batch must freeze a source-separated presence
observation and its stop/adoption gate before scoring; low, quiet, short and gap
controls plus independent recorded gates remain required. No NS-3 or NS-5 credit
changes. This is one nonclosing batch under the changed source approach.

## Presence F0 comparison and stop point — 2026-09-22

The fixed Pascal companion audit matched all 137 source-bound immediate post-end
candidate windows against the same URMP parts' 46-ms frame-pitch annotations.
All 137 frame windows start after the preceding note end and are annotated
unvoiced; none retains that note's pitch or another pitch. Controls find the
preceding pitch at 1,440/1,441 internal-note centers and unvoiced annotations
at 439/439 distant rests. Every F0s and Notes file matched the existing bound
manifest. Checked stable FPC 3.2.2 Win32 compilation had no warnings; two
final runs produced identical `build/presence-contrast/f0-audit.csv`, SHA256
`5504aff291af64df025a1b152947ed8ae2b05fb6d64b9fc2501d53e1edeb6d72`.

The frame and note annotations are related products. Unvoiced F0 does not prove
there is no acoustic decay; it means this packet cannot independently label a
voiced release tail. This is the second consecutive nonclosing presence batch.
Stop the URMP annotation-only route and obtain separately anchored gate/release
evidence plus physical controls before a new scorer. Keep these 137 rows
unresolved, preserve Spring and held-out material, and do not change the native
event path or award NS-3/NS-5 credit. The source-bound packet itself remains
available for later comparison.

## Presence contrast reference packet — 2026-09-22

The NS-5 scale chain requires `NS-3_notes_03`, which in turn requires recorded
note presence and boundary acceptance. For `NS-3_notes_02`, a frozen Pascal
selector used the already bound six URMP part WAV/Notes pairs from three distinct
work groups. The first 30 seconds of each produced 1,441 internal continuation,
137 immediate post-end candidate and 439 distant-rest windows at fixed 50-ms
centers; 1,577 were excluded. Exact group, source/annotation hashes, frame and
RMS rows, including the nearest preceding note index for post-end candidates,
are in ignored `build/presence-contrast/cohorts.csv`, SHA256
`393e175f3237b4ff1b5f241645d929eb3c3974e3820606d0f6bbdf15fc0e7d85`.
Checked stable FPC 3.2.2 Win32 compilation and two byte-identical complete runs
passed after repairing the post-end note-index binding. The binding manifest SHA256 is
`f87c398357641b2bc6893e98263f8981f9669787a7802f9d69b919222f47786c`.

The post-end cohort is **not** an acoustic release-tail truth set. The next
bounded action is adjudication of release versus rest on those fixed windows,
keeping uncertain endpoints explicit, followed by a source-separated observation
and frozen scoring gate. No predictor, saved learner bridge, NS-3 criterion or
credit is accepted from the packet. This is one nonclosing presence batch after
the prior reassessment; a second without criterion closure triggers the task-flow
checkpoint. Spring development and reserved phrase material were not read.

## Isolated NS-5 reference candidate screen — 2026-09-22

The directly published full `Chill.wav` from Pro Sensory was acquired into ignored
`build/style-reference-source/` and decoded with Pythian's Pascal WAV reader on
checked stable FPC 3.2.2 Win32. Exact SHA256, page/license/attribution, 230.365170-s
clock and signal checks are recorded in the [stopped source packet](STYLE-CARDS.md#pro-sensory-isolated-source-rejected--2026-09-22).
This was a separate candidate family, not an authenticated correspondence to
C-early; its later whole-track listener verdict rejected it. No required musical
annotations or quantitative reference thresholds are available, so `NS-5_evaluation_01` remains
open with zero added credit; NS-5 stays 27%, overall 63.15%.

The earlier chapter-correspondence batch and this isolated-source batch did not
close a criterion. At the two-nonclosing-batch checkpoint, stop source browsing
and change the next action to review of this exact WAV or another independently
identified full recording, with timed observations for all six required style
dimensions. Do not infer them from tags or signal levels. The user's 20-attempt
same-cause limit and 20-failed-QA-submission transfer threshold remain in force;
this source screening is not an inference attempt or failed QA submission.

## Sparse-peak pitch decision rejected — 2026-09-22

The accepted Pascal sparse-peak observations give high reference-pitch top-12
recall but do not themselves decide register. A one-shot, non-fitted development
gate for [note identity](TODO/NS-3_notes_01.md) froze a best-bin decision with
support >=0.5 and an octave-alternative margin of 0.15 before scoring the
Spring references with this rule. The source-bound Pascal scorer evaluated only
the original fully contained single-note centers. Flute admitted 892/905, with
814 correct, 44 octave-wrong and 34 other-wrong (91.256% precision). Violin
admitted 1083/1355, with 961 correct, 82 octave-wrong and 40 other-wrong
(79.926% coverage, 88.735% precision). Flute fails the fixed >=98% precision
gate; violin fails both >=80% coverage and >=98% precision. The Win64 FPC 3.3.1
analysis took 125 ms per saved 3000-center file and reported zero unfreed heap
blocks. The declared private-memory cap was not measured after the accuracy
failure, so no memory qualification is claimed. The policy,
Pascal source and exact source/reference/observation hashes are in ignored
`build/note-sparse-identity/`.

This is a scientific rejection, not a maintained implementation defect. Stop
the direct-support identity rule without a threshold/rank sweep. The independent
phrase material stays untouched, and no task criterion or credit closes.
Accepted sparse-peak support remains useful as an observation; separate
[presence and boundaries](TODO/NS-3_notes_02.md) still need contrasting
continuation/release/rest evidence. The existing NS-5 style cards still need
verified recording editions and curator-reviewed musical references. Current
completion remains NS-3 39%, NS-5 27% and overall 63.15%.

The stopped source-separated register scorer (batch 28) and this stopped
direct-support rule are two nonclosing batches in the note-identity investigation.
The successful inference work between them did not resolve the note-identity
cause. Athena's checkpoint changes the next action: suspend best-bin, rank and
threshold variants. Resume `NS-3_notes_01` only with independently contrasting,
frozen register evidence and prospective ambiguity/coverage behavior, including
low/quiet/short protections. For the primary NS-5 chain, the recorded source
edition and curator review input remains the exact external unblock condition;
the user has been asked to supply sources/review or choose replacement references.

## Supervised Pascal WAV inference accepted — 2026-09-22

Focused QA accepted all five criteria of [NS-3_validation_02](TODO/DONE/NS-3_validation_02.md)
after the selected 2048-sample Pascal backend was connected to the maintained
supervised WAV path. Both original Spring parts match the earlier label-blind
producer salience at every one of 1,080,000 bins, six rate/channel cases pass,
batch-size replay is exact, and wrong-source rejection and timed cancellation
preserve the accepted artifact. The 48-kHz stereo five-minute case publishes
30,000 observations in 137,719 ms. The 16-kHz stereo continuous-hour case
publishes 360,000 verified observations in **1,247,313 ms**, with 6,582,272-byte
peak worker private memory against 3,630,000-ms/2-GiB limits. Exact middle
and final 30-second scoped replays match every observation byte in the hour
artifact. The published hour PINF SHA256 is
`bf63ebc3c7d989eed90ddf2f928e366c414bbd9286e741c2de7aa0609420f822`.
The supervisor reports zero unfreed heap blocks; this is not a worker heap
trace. Exact identities, bounded budgets and ignored logs are in the DONE task.

The rejected periodic-support unit and fixture are trimmed from the unmerged
branch; their failure evidence stays in the dated record and Git history.
The execution task earns its assigned **+3 NS-3 goal points / +0.75 overall**,
bringing **NS-3 to 39% and overall to 63.15%**, with **37 open / 14 DONE**
tasks across 19 active outcomes. The historical TensorFlow C and Beat This!
ONNX Runtime paths remain retired. Raw support is not note admission,
independent provider accuracy or genre style learning. The next NS-5 style-card
deliverable still needs verified recording/edition correspondence and
curator-reviewed musical observations;
the admitted-note-to-saved-learner bridge also remains open before the broader
multi-recording workload can earn acceptance.

## Supervised sparse-peak integration batch — 2026-09-22

The [execution-task](TODO/DONE/NS-3_validation_02.md) short batch replaces the rejected
1024-sample WAV worker with the accepted 2048-sample policy. Checked stable
FPC Win64/Win32 geometry/replay/policy fixtures pass. The supervised Spring
flute/violin jobs each publish 3000 source-bound observations in 10,234/10,203
ms, with 6,569,984/6,590,464-byte peak worker private memory; all 1,080,000
salience bins per part equal the saved label-blind producer outputs. Flute
batch-size 1 and 32 PINF hashes match exactly. Six two-second rate/channel
fixtures (16/44.1/48 kHz × mono/stereo) pass; exact identities and hashes
are in the task. Wrong-source rejection and timed mid-run cancellation leave
the earlier accepted PINF unchanged. Focused QA finds no short-path defect.

Criterion 1 and short-source portions of criteria 4-5 are satisfied; criterion
3's sustained cost and the hour failure/replay qualification remain open, so
the task earns zero credit. The next bounded batch measures the 48-kHz stereo
five-minute case against 330 seconds/2 GiB; only a plausible pass proceeds to
a verified 360,000-observation hour against 3,630 seconds/2 GiB. Stop at the
first failed gate and do not retune estimator or recorded scores. The
short-batch handoff closes an acceptance criterion, resetting the separate
two-nonclosing-batch checkpoint; the user's 20-attempt cap remains available
for genuine later failure cases, not this successful integration.

The five-minute 48-kHz stereo channel-1 case now passes in **137,719 ms**
with 30,000 verified observations and 6,574,080-byte peak worker memory;
the supervisor reported zero unfreed heap blocks. The source/PINF hashes are
in the execution task.
The twelvefold 1,652,628-ms extrapolation leaves margin under the fixed
3,630,000-ms hour cap; it is only a decision to run the hour. The hour uses
the previously verified 16-kHz stereo `C-native16k.wav`, first 3,600 seconds
and a full 2048-sample last-window input halo; any budget or artifact failure
stops the case without claiming task credit.

The conditional continuous-hour case passed: the checked stable Win64 worker
published 360,000 verified observations from the bound 16-kHz stereo source
in **1,247,313 ms**, with 6,582,272-byte peak private memory and no remaining
staging artifact. The supervisor reported zero unfreed heap blocks. Published
PINF SHA256 is
`bf63ebc3c7d989eed90ddf2f928e366c414bbd9286e741c2de7aa0609420f822`.
Separate supervised middle and final 30-second scopes match the hour artifact
exactly at every observation byte, using the same full source-clock support.
The exact child identities/hashes and scope limits are recorded in the
[execution task](TODO/DONE/NS-3_validation_02.md). This complements the six
rate/channel cases and short Spring source-bound fidelity. Focused final QA
still decides whether the execution task can close; no credit is recorded yet.

## Selective Pascal observation accepted — 2026-09-22

The fifth frozen producer hypothesis now passes every criterion of
[NS-3_validation_03](TODO/DONE/NS-3_validation_03.md), following focused QA of
its backend and separate Pascal recorded scorer. Checked stable FPC 3.2.2
Win64/Win32 synthetic controls pass; the Win64 3000-window screen took
9,563 ms with checksum `54.0764845667` and zero unfreed blocks. Hash-bound
Spring flute/violin saved outputs pass the predeclared top-12 and <=36-bin
density gates: 905/905 and 1355/1355 ranked hits; active/rest mean bins >=0.5
are 4.832/0.924 and 7.027/0.152. Reference support >=0.5 occurs at 889/905
and 1320/1355 active centers. The source-bound flute output replays to the
same SHA256. One scored window per part touches an adjacent note annotation
by less than 1 ms but satisfies the predeclared fully contained target-note
center rule. Exact identities and ignored logs are in the accepted task.

The backend is owned Pascal, returns raw support rather than admitted notes,
and earns **+2 NS-3 goal points / +0.50 overall points**. Current completion is
**NS-3 36%; overall 62.40%**. The remaining [supervised execution task](TODO/DONE/NS-3_validation_02.md)
owns the retained +3 NS-3 points and has no current credit. Its next bounded
deliverable is a maintained 2048-sample WAV consumer that preserves source,
policy and output identity and passes short rate/channel and failure/replay
checks before the continuous-hour qualification. The 20-attempt limit remains
the project stop rule; attempt five succeeded and does not increment an
unsuccessful-attempt count.

## Retry-limit revision — 2026-09-22

The user raised Pythian's same-cause unsuccessful-attempt limit from four to
**20**, and the delegated-task QA ownership-transfer threshold from two to
**20 failed submissions** in [task flow](TASKFLOW.MD#select-and-execute).
The Pascal observation ledger is now **4/20**; earlier `4/4` statements record
the limit then in force. The fourth attempt's 31,782-ms cost failure and its
rejected repair remain evidence, not a passing producer. Athena's separate
two-nonclosing-batch checkpoint still requires reassessment and a changed
action; the larger retry allowance does not turn blind variations into an
accepted strategy. No acceptance credit or task count changes.

The twentieth same-cause failure is a hard stop for that experiment and starts
a diagnostic review; renaming or retuning it cannot reset the ledger. The
twentieth failed QA submission likewise stops helper resubmissions and transfers
the task and its evidence to the primary agent for diagnosis and repair.

The next producer decision is frozen in [NS-3_validation_03](TODO/DONE/NS-3_validation_03.md):
attempt five keeps the Pascal 2048/8192 peak evidence but bounds each
35-cent Gaussian projection at eight sigma, calculating a continuous pitch
coordinate once per peak and visiting only nearby grid bins. The discarded
tail is <=1.27e-14 of path amplitude, with a new estimator/policy identity.
This targets the observed 31,782-ms dense projection cost rather than changing
the failed gate. Controlled checks and the same <=30-second 3000-window
screen precede the untouched Spring recall/density thresholds and 64-ms
fully-contained scoring rule. Stop at the first failure, with no label tuning.
The ledger remains **4/20** until this fifth candidate is actually tested.

## NS-5 comparator replay specification — 2026-09-22

While source/edition and curator musical review for the three style cards is
pending, the independent comparator-specification batch fixes the exact
[within-recording permutation](STYLE-CARDS.md#replayable-within-recording-permutation--specification-v1).
Complete units are canonically ordered and permuted by SHA-256 digests of
source/policy identities, recording and scope IDs, dimension and frozen global
seed; no platform RNG is used. The output ordinal list and identity-avoidance
flag are recorded, and immovable scopes are unsupported. This directly
advances criterion 3 of [NS-5_evaluation_01](TODO/NS-5_evaluation_01.md),
with no claim that the genre cards, numerical gates or controlled trait
comparisons are complete. Next evidence is focused protocol QA; stop this
batch if the rule leaves ambiguous scope membership or replay bytes. No
task credit changes.

Focused QA found two interpretation gaps and both are now frozen in the
same specification: transitive compound bars retain held events within one
song/meter scope; a hold crossing scopes makes that scope unsupported; and
a permutation that changes no target relationship is reported as no-effect,
without redrawing. Exact dimension tags are fixed. This completes the
**specification-only third criterion** of NS-5_evaluation_01, while the
reference-grounded cards, numerical gates and controlled trait comparisons
remain open. No task credit changes.

## Periodic-support recorded stop point — 2026-09-22

This section records successive decisions in reverse order. The active
direction is the fourth-attempt stop immediately below; the third reassessment
created the task split, and older forward plans are historical.

The bounded repair of the fourth implementation kept the same controlled
mixture values against the old compiled Pascal unit and passed all Win64
synthetic controls. Checked Win64/Win32 builds passed; the Win64 3000-window
screen took **31,782 ms**, 1,782 ms beyond the fixed 30-second limit, with
zero owned leaks. Its backend-only hour extrapolation is 3,813,840 ms for
360,000 windows, above the 3,630,000-ms whole-job limit before decoding,
source checks or publication. No Spring input was read. The repaired source
is rejected and trimmed; ignored comparator/build/run logs remain under
`build/native-inference-peakmap/`. This is a failed repair of attempt four,
not a fifth estimator hypothesis. Under the then-current 4/4 cap and the
two-nonclosing-batch checkpoint, it required a different observation
architecture/cost decision; the later 20-attempt revision is recorded above,
while the larger goal can continue on other ready work. No points change.

Fourth hypothesis result: both checked FPC 3.2.2 target builds passed, and
Win64 synthetic controls passed, including support 0.999916732 / 0.666605532
for the 55+110-Hz mixture. The 3000-window backend screen then exceeded its
fixed 30-second deadline; the process had consumed more than 85 CPU seconds
when stopped. There is no completed throughput checksum or final heap report.
No Spring recording or reference was read. The prototype is trimmed from the
unmerged branch, leaving ignored build/partial-run logs at
`build/native-inference-peakmap/`. This is rejected attempt **4/4** for the
Pascal producer cause. The synthetic result does not select a backend because
its real-time cost failed before recorded scoring. Stop this estimator search;
reassess the observation contract and complexity together, rather than
making a fifth window, normalization or threshold variation. The split tasks
remain open with zero new credit; accounting stays **61.90%, 39 open / 12 DONE**.

Focused cost reassessment found a concrete avoidable loop in that stopped
implementation: up to 64×64 harmonic peak-pair agreement checks, including
`Log2`, were repeated for each of 360 output bins although pair agreement is
independent of the bin. A single mechanical repair may hoist that calculation
and project qualifying pairs once, retaining every frozen measurement equation
and the 4/4 ledger. Compare controlled output to the stopped binary where
available, then rerun only the exact 3000-window <=30-second cost gate before
any Spring input. If the same cost gate fails, stop this candidate. This
reassessment changes execution order, not the estimator or its acceptance
thresholds; no credit is awarded.

Fourth bounded producer decision: the first two spectral probes gave the
weaker 110-Hz mixture tone support near 0.2 because their candidate power was
normalized by total spectral power. The nominal peak probe also used a
neighborhood maximum at every candidate pitch, without detecting physical
peak locations. The final attempt therefore changes representation to
detected, frequency-interpolated local maxima with direct magnitude-relative
support and a separate peak-concentration gate. The exact 2048/8192 geometry,
0.03 concentration threshold, 35-cent Gaussian sigma, 64-peak selection,
ambiguity formulas and synthetic/cost checks are frozen in
[NS-3_validation_03](TODO/DONE/NS-3_validation_03.md) before implementation.
The Spring recall/density thresholds remain unchanged; its center exclusion
is widened from the rejected 1024-window scorer's 50 ms to 1024 samples
(64 ms) per side, before any fourth-hypothesis scoring, so scored windows
are fully inside a reference note or rest.
Zero padding interpolates the spectrum; it does not identify overlapping
sources or establish a new information limit. Failure at the controlled,
cost or recorded gate will exhaust this cause's four-attempt cap and trigger
reassessment, not a fifth threshold or window variation. No credit changes.

Third hypothesis update: a 2048-sample direct-peak/harmonic-ambiguity Pascal
probe compiled on checked Win64/Win32, passed the 440-Hz tone and replay, then
stopped on the fixed 55+110-Hz mixture. Its 55/110 supports were 0.460238546 /
0.203423500; the latter failed the >0.3 gate. No later synthetic, throughput,
Spring or hour evidence was collected. The rejected source is trimmed from the
branch; its ignored compiler and zero-leak run logs remain under
`build/native-inference-peaks/`. This is attempt three of four for a viable
Pascal producer. The sparse-spectrum and peak-evidence batches are two
consecutive nonclosing batches after the prior review. Reassessment chooses a
task split at the independently useful selective-observation boundary, leaving
long-source execution with its current task. Do not start a fourth estimator
variation without a distinct evidence-backed decision and frozen stop gate.
The new [observation task](TODO/DONE/NS-3_validation_03.md) owns controlled and
recorded selectivity and 2 of the original 5 unearned NS-3 points; the
[execution task](TODO/DONE/NS-3_validation_02.md) retains source/policy binding,
long-source cost, supervision and 3 points. The existing downstream blocker
on execution remains. This adds one open file and one dependency edge, with
**39 open / 12 DONE, 51 tasks, NS-3 34% and overall 61.90%**. No points are
awarded for the split.

Second hypothesis update: a sparse harmonic spectrum probe using the Pascal
1024-point Fourier primitive passed checked Win64/Win32 builds but stopped at
its controlled 55+110-Hz mixture gate. Support was 0.464351296 at 55 Hz and
0.195154965 at 110 Hz; the frozen gate required both above 0.3. No Spring
recording or throughput cost was scored, and no strategy criterion was closed.
The rejected prototype is trimmed from the unmerged branch; ignored compiler
and zero-leak run logs remain at `build/native-inference-spectral/`. This is
attempt two of the user's four-attempt cap for a viable Pascal producer. The
next bounded decision must address frequency resolution and harmonic overlap
with explicit peak evidence; simply increasing the FFT size or changing a
threshold would repeat the same unresolved inference question.

The next batch therefore tests a 2048-sample Pascal window with direct local
spectral peaks and separately evidenced harmonic ambiguity. Its fixed low-tone,
mixture, silence and replay controls are in the reopened task, followed by the
unchanged Spring recall/density and cost gates. Stop at the first failed gate;
the third hypothesis earns no provisional credit from a compile or synthetic
pass alone.

At the original periodic-support stop, the user raised the project limit for
unsuccessful attempts on the same cause
from two to four in [task flow](TASKFLOW.MD#select-and-execute). The separate
Athena two-nonclosing-batch checkpoint still requires a change of action after
review. That was the first rejected estimator hypothesis under the four-attempt
cap; the prior short component checks were part of that same hypothesis.
The second hypothesis and its synthetic stop are recorded immediately above;
the Spring gate below describes the predeclared plan, not an executed score.

The first Pascal backend is executable and fast, but recorded evidence retracts
its provisional strategy acceptance. Its absolute normalized autocorrelation
gives high true-pitch candidate recall on the first 30 seconds of the bound
Spring flute/violin parts (98.40%/100% among the top 12 separated candidates),
yet support >=0.5 covers an average 201/360 flute bins at labeled notes and 203
at rests; violin covers 87/360 at notes and 199 at rests. Nearly every labeled
rest has maximum support >=0.5. The predeclared recall-only gate therefore did
not establish useful discrimination. The Pascal scorer excluded 50-ms note
edges and used reference labels only after the source-bound observations were
saved. Exact counts, policy and source/reference identities are in the
[reopened task](TODO/DONE/NS-3_validation_02.md).

Both 30-second jobs completed in about 2.3 seconds; the separate five-minute
48-kHz stereo job completed in 57.797 seconds with 6,578,176-byte peak worker
private memory. The hour cost run was stopped after the failure became clear;
no hour artifact or qualification was accepted. Preserve the earlier short
build/replay/source-rejection evidence as component evidence, while withdrawing
the claim that criterion 1 selected a viable production strategy. Two batches
had failed to establish that acceptance. The next action at that checkpoint
changed the estimator hypothesis to sparse harmonic spectral support using
the existing Pascal Fourier primitive. A dual gate was frozen before
implementation: at least
80% reference candidate recall among 12 separated candidates on each part,
and at most 36/360 bins with support >=0.5 on average for both scored notes and
rests, with unchanged job cost/memory limits. If that failed, the plan was to
reassess window or representation geometry instead of tuning the same
recordings. At that checkpoint, the existing inference task owned these
criteria and no split was justified. The later split is recorded above.
Accounting then was **61.90%, 38 open / 12 DONE**.

## Pascal-only inference requirement — 2026-09-22

The later recorded stop point above supersedes this section's provisional
strategy-criterion conclusion; the Pascal-only architecture requirement remains.

The user explicitly requires Pascal only, with no exception for an optional
TensorFlow or other third-party execution runtime. This overrides the former
Win64 inference-adapter decision. Athena's principles, coding, dependency,
validation, stewardship and shared task-flow rules were reread before this
change. Core, maintained analysis/tools and all new inference experiments must
be Pascal-owned with FPC/RTL. Existing model/runtime research remains
historical evidence with its notices and source lineage, not a supported path.

[NS-3_validation_02](TODO/DONE/NS-3_validation_02.md) is reopened; its +5 NS-3 points
(+1.25 overall) are withdrawn. Current accounting becomes **NS-3 34%, overall
61.90%, 38 open / 12 DONE**. The frozen earlier external-runtime hour, numerical
and cancellation results still describe that old implementation; they cannot
qualify the replacement. Downstream note, timing, mixture, scale and final
delivery tasks retain or gain a real blocker on the reopened producer. The
former adapter, asset acquisition and runtime fixture were removed from the
maintained paths. Git history and [provenance](PROVENANCE.md#optional-native-observation-adapter)
retain their exact source and notices; no copy is kept in the new library.

The first replacement criterion now has a concrete Win64 producer: the owned
periodic-support backend runs through the source-bound supervised Pascal WAV
consumer with a new exact policy/estimator identity. Checked FPC 3.2.2 Win64
build and short 16-kHz mono/48-kHz stereo jobs pass. Batch-size replay is
byte-identical, wrong-source rejection preserves output, and the Win32 backend
fixture also passes. The 3,000-window probe is a bounded cost screen only;
recorded fidelity, full duration/cancellation/failure QA and final target
delivery remain unaccepted. Exact results and artifact SHA256 are in the
[reopened task](TODO/DONE/NS-3_validation_02.md). No task credit changes. Its
existing five criteria own the replacement work, so no additional task is
needed at this checkpoint. Next, check recorded-input fidelity and a
representative sustained-source
cost under the new policy, with a stop/switch decision if either fails. The
separate NS-5 reference-review input remains pending. Paired QA confirms the
NS-2 processing matrix and NS-5 protocol notes match their stated artifacts and
scope; no listening or style completion is claimed.

## Resume and reference stop point — 2026-09-22

The user explicitly resumed the broader goal and its authorized helper/QA cycle.
The checkout began clean on `hello-pythian` at `9ec95a1`; the least-complete
north star is NS-5. The first work batch on resumption advanced the first
criterion of [NS-5_evaluation_01](TODO/NS-5_evaluation_01.md): a source-bound
screen of its three existing candidate cards. Its deliverable is the
[recording correspondence table](STYLE-CARDS.md#recording-correspondence-screen--2026-09-22);
closing evidence would be verified source/edition/cut correspondence and reviewed
musical annotations for every required dimension on all three cards. The stop
condition is reached: retained declarations and published catalogue lengths
cannot authenticate the WAV editions or supply musical annotations. The declared
chapters differ from published lengths by one, one and seven seconds. No card or
quantitative genre criterion is accepted, and no new genre threshold is frozen.

Batch 28 and this correspondence screen each closed no acceptance criterion.
The independently delegated [NS-2 source audition matrix](SYNTHESIS-QUALITY.md#finite-listening-matrix--ns-2_synthesis-quality_01)
was completed in parallel and closes the first criterion of
[NS-2_synthesis-quality_01](TODO/DONE/NS-2_synthesis-quality_01.md), subject to
final QA. It maps existing source-family artifacts and sampled ranges without
new renders. Actual timestamped listening, family verdicts, possible repairs and
accepted operating ranges remain open. Because that parallel batch advances a
criterion, this record does **not** assert two consecutive nonclosing project
batches or reset a task-specific failed-approach history.

The source screen still gives a concrete NS-5 stop point. Stop catalogue/level-only
investigation and obtain independently reviewed source/annotation input or
replacements before another style-reference batch. A request for that input is
pending. The exact unblock is a checked recording and cut for each candidate plus
beat/meter, groove, harmony, role, sound/envelope and phrase/section observations
with method and uncertainty. Automatic transcription is not required. The
existing task and 4-point NS-5 credit remain open and unchanged. Independent
sound-quality work may proceed while this external input is pending; it cannot
stand in for the style reference packet. QA and publication follow the delegated
workflow with these two components ready.

## Task development notes — 2026-09-21

At the user's request, all 50 task files, including the 13 in DONE, now end with
**Dev Notes:**. Twenty-four tasks summarize existing failed approaches, repaired
defects or concrete follow-ups with evidence/owner links; the remaining 26 state
that no failed approaches or follow-ups are recorded yet. Existing descriptions,
acceptance criteria, prerequisite lists and completion evidence are preserved.
The local task-flow template now requires this section for future tasks and
defines its relationship to blockers, discovered gaps and stopped experiments.

This is an authorized documentation update while the broader goal remains
paused. No sub-agent is resumed, experiment restarted, task moved or completion
credit changed: **63.15%, 37 open / 13 DONE**. Documentation checks pass: all 50
original task bodies are unchanged and have one final nonempty Dev Notes section;
1071 local links across 53 files resolve. The existing native task checker, updated
for the section boundary, confirms 96 acyclic prerequisite links, final-gate
reachability and unchanged credit arithmetic with zero unfreed blocks.
`git diff --check` passes. Publish this documentation on `hello-pythian`.

## Listener preview — 2026-09-20

Supplied a native 30-second paired synthesis preview for listener feedback:
15 seconds of the saved-trajectory baseline, then the same passage with melody
timbre edited. Shared 12-times listening gain and 10-ms cut-edge fades preserve
relative balance. The library WAV path produces and reopens exactly 1323000
stereo frames at 44100 Hz; peak 0.593627930, no unfreed blocks on checked stable
Win64. Source, logs and audio are ignored under `build/listener-preview-20260920/`.
The [listening record](SYNTHESIS-QUALITY.md#thirty-second-listener-preview--2026-09-20)
binds the artifact and remaining scope. Feedback is pending; FUND-QUALITY stays
open and the milestone estimate remains 55.5 weighted points. The six north stars
still map to 22 unfinished outcomes, with dependency links and 32 conditional
points assigned to the next five outcome milestones. No synthesis algorithm,
model, format, dependency or completion claim changes in preparing this preview.

The preview artifact was rechecked against its recorded SHA256 before attaching
it for playback. The milestone acceptance dashboard now condenses timing and
note experiments into current capabilities and remaining blockers, linking the
full topic evidence. No listening verdict or additional completion is inferred.

## Pause retrospective — 2026-09-21

The user requested that all sub-agent work stop, that the north stars and task
criteria be reviewed, and that the goal then pause to conserve the remaining
weekly budget. The implementation helper's read-only reassessment was interrupted;
QA was already idle. No new implementation, model run or held-out evaluation was
started. The intervening Athena check confirmed the already-published pin and
was status verification, not additional capability progress.

| North star | Accepted completion | Retrospective and remaining task ownership |
| --- | ---: | --- |
| NS-1 foundation | 100% | Extraction, independence and Phanes removal are accepted; preserve their contracts rather than reopen them. |
| NS-2 synthesis | 80% | Numerical and rendered evidence exists; source, processing and combined listening acceptance remain in the three synthesis-quality tasks. The preview has no recorded listener verdict. |
| NS-3 WAV learning | 39% | Validation, bounded observations and reference preparation are accepted. Register/presence, automatic context and actual mixture inference remain accuracy bottlenecks in the existing 14 tasks. |
| NS-4 WFC composition | 96% | Granular passes and semantic blend/reblend are accepted. The remaining integration task requires accepted recorded providers and listening; 96% is not end-to-end musical success. |
| NS-5 styles | 27% | Corpus identity and mechanics are baseline capability. All three genre verdicts remain unaccepted; the 16 open tasks cover references/corpora, vocabulary, scale, continuity, structure and blends. |
| NS-6 delivery | 72% | Native checkpoint and consumer contract are accepted. Final workflow packaging, independent use and the final audit remain open. |

The catalog remains **50 tasks, 37 open / 13 DONE, 96 dependency edges**.
Overall scope accounting remains **63.15%**, with **36.85 points** outstanding.
Musical learning and corpus/style quality own **29.85** of those points. The
20.85-point sound/learning/integration package and 16-point style/delivery package
still map the full destination; neither is reduced to a diagnostic milestone.

Recent progress has been uneven: the measurement/reference preparation split
delivered two independently usable tasks (+0.50 overall), while the subsequent
fixed register-candidate experiment failed its flute gate. Its verified rejection
changes which approach is viable, but supplies no accepted inference capability.
The remaining work is dominated by musical discrimination and grounded references,
not missing generic APIs. More reports or renamed model variants would repeat
the pattern without meeting the user's goal.

### Criteria corrections and task coverage

- [Note identity](TODO/NS-3_notes_01.md) now explicitly requires audio-derived
  candidates for final scoring, separated fit/calibration groups when fitting,
  and prospective abstention/coverage accounting. Oracle-ranked candidates do
  not demonstrate blind inference.
- [Presence and boundaries](TODO/NS-3_notes_02.md) now explicitly require labelled
  continuation/release/rest contrasts and separate missed-note, false-rest,
  boundary and unknown results. A pitch score cannot stand in for presence.
- [Mixture learning](TODO/NS-3_parts_02.md) explicitly carries the external
  crossing/unison/quiet-ownership/reference-coverage gaps into its acceptance
  comparisons. Preparation acceptance does not settle them.
- [Style specification](TODO/NS-5_evaluation_01.md) now binds reference identity,
  intervals and annotation uncertainty explicitly, and requires preserving/breaking
  controls for each required provider dimension. Its previous single-comparison
  wording could let a level-only control appear to qualify musical comparators.

These are clarifications of required end-state evidence, with the style-control
check strengthened to cover its full declared scope. All identified gaps already
have task owners; no new task, dependency, format or completion credit is needed.
Accepted DONE criteria and evidence are unchanged. No completed capability was
disproved by this retrospective. This is a backlog/evidence review, not a fresh
runtime or listening acceptance audit.

### Resume decision and stop state

1. Resume the ready NS-5 style-reference specification first. Resolve candidate
   recording/edition correspondence and supply the missing musical annotations
   using curator or explicitly reviewed references; automatic transcription is
   not a prerequisite. Close its full specification or identify the exact missing
   reference/review input. Do not substitute another aggregate-level study.
2. Keep the source and processing listening matrices finite under NS-2; reuse
   existing audio, identify the required reviewer evidence, and retain pending
   verdicts honestly. No listening result is inferred during this pause.
3. Return to note identity/presence with an evidence-backed decision that explains
   the unresolved ambiguity before implementing another experiment. Preserve
   the true low/quiet/short/gap controls and untouched phrase material. Once
   notes_01/02 pass, follow notes_03 into mixture learning and semantic scale;
   context has its own tempo/local-key prerequisite chain.

Batch 28 remains stopped. The consecutive no-criterion-closure count is **one**;
the pause, this retrospective and agent handoffs do not reset it. No next
experiment is authorized by this note. If the next work batch closes no criterion,
apply the mandatory two-batch reassessment before a further batch. Do not split
diagnostics into nominal DONE tasks or weaken gates to manufacture progress.

The primary performs only proportional documentation checks for this requested
retro; the user's stop on sub-agent work takes precedence over scheduling QA.
No feature is accepted or moved to DONE. Final feature QA delegation remains the
standing workflow when work is explicitly resumed. Publish the review on
`hello-pythian`, then leave the goal and sub-agent work paused.

Documentation verification passes: 742 local links across the seven changed
files, all 50 task templates, 96 acyclic prerequisite links, reachability of the
final completion gate and unchanged credit arithmetic. The existing native
task checker reports zero unfreed blocks; `git diff --check` passes. No runtime
suite or scientific experiment was repeated for this documentation change.

## Previous handoff — source-separated register calibration — 2026-09-21

The previous goal turn made progress: all criteria of parts_01 were accepted,
the task moved to DONE and `7dac111` published the matching records. Continue
the same NS-5 prerequisite path through recorded note identity/presence, then
independent phrases. Overall completion is **63.15%**; no musical provider or
genre verdict was added by reference preparation.
Exact-revision CI run 35645881135 is verified successful.

Before batch 28, the primary and implementation helper reassessed the stopped
register and presence approaches. Periodic/phase measurements preserve coherent
lower-register explanations of the flute errors; separate learned heads and
contour support fail low-short-note or true-gap controls. The preceding event
decoder already locally favors notes at many false-rest centers. Another global
cutoff, donor ordering or decoder weight does not supply missing discrimination.

The new bounded hypothesis belongs to notes_01: fit candidate-conditioned
temporal harmonic features from separate labelled recorded works, then test a
separate work before using the scorer on existing development material. The
fixed experiment is described in [phrase evidence](PHRASE-EVALUATION.md#source-separated-candidate-calibration--2026-09-21).
It targets register evidence; presence/boundaries remain separately required.
No signal-strength score is promoted to a calibrated note-presence probability.

The source contract, reviewed work identities, fit/challenge split, forty
features, fixed logistic fitting and stop gate were frozen before measurement.
Native feature/control and fit/driver components pass checked stable Win64 QA.
Only the selected source works were extracted
from the already bound archive. Related arrangements stay grouped/excluded,
existing Spring stays development, reserved phrase material remains untouched,
and the accepted role-reference supplement is not training data.

The fixed fit/challenge is complete. Violin ranks 546/548 centers correctly;
flute 482/514 fails 98%, with 100% eligible coverage and no ties for either part.
These are oracle candidate ranks, not blind inference accuracy. The model uses
4148 fit rows only and is frozen before challenge observation. The proposal is
**stopped**: no Spring application, feature/epoch/threshold variants or production
adoption follow. Aggregate failure does not identify its cause or establish
impossibility of every supervised/selective observation approach.

Physical/numerical controls, exact 13-file replay, resource bounds and rejection
preservation pass with zero leaks. Runs take 18290/18349 ms and 28,684,288 sampled
private bytes, under 120 seconds/256 MiB/64 MiB. Manifest
`928e6a1a23b7ddaeeb14a3e73e14b9c1017f6b7ec241a459bcfae0c2c7cd300f`
binds the 1,805,303-byte packet; full report is `build/qa-batch-28/report.txt`.
Both implementation failure counters are zero; no live handles remain.

No task criterion closes; the consecutive no-criterion-closure count is **one**
for the completed batch 28. Keep **63.15%, 37 open / 13 DONE** and all prerequisites
unchanged. Source/policy identities and the scientific stop are recorded in the
owning task. Before another note proposal, define how candidate ambiguity and
presence will be distinguished or explicitly left unknown, with prospective
source-separated confidence/coverage and unchanged waveform protections. This
cannot be a post-hoc threshold on the failed calibration ranks. The task-flow
checkpoint requires reassessment before a third batch without criterion closure.

Final documentation QA passes: 2731 local links, the 50-task/96-edge graph,
unchanged accounting, evidence meaning, privacy and whitespace checks reconcile.
The five-document update is ready for branch publication.

## Previous checkpoint — external reference task accepted — 2026-09-21

Batch 27 closes the remaining AC2 of
[parts_01, now DONE](TODO/DONE/NS-3_parts_01.md). Earlier batches accepted
source/local-role binding, qualified development/evaluation families, frozen
policy application and the two-family native packet. The
[curator supplement](PART-EVALUATION.md#curator-acoustic-reference-supplement--2026-09-21)
adds useful bass/chordal/lead/other intervals and sets with explicit uncertainty.
All five contributors remain; native import validates 501 complete-source rows
and retains 258 events in the first 30 seconds. Primary role review covers the
first 20 seconds, leaving 1000 unknown centers per role. The family remains
provisional, with reference-only exposure and unknown model-training overlap.
The producer's paired-corpus seconds convention is retained; historical converter
latency and original-sample equivalence remain unverified.

Final checked stable Win64 QA accepts source preparation, import and assembly:
exact replay, resources, rejection preservation, unchanged raw annotations and
both relocated maintained CLI reports. The 53-file supplement totals 13,145,367
bytes, manifest `a51914984c5e10d83056625d524f9b7eab1b943e610f3baed57983318881f960`.
Copy matches 56/32/29/32 scorable timing events for bass/chordal/lead/other;
omission misses them. Unknown-reference claims remain excluded and every
accuracy/independence verdict stays false. Evidence is retained in
`build/qa-batch-27/report.txt`; [consumer instructions](PART-REFERENCE-PACKET.md)
cover reconstruction and scoring.

Three root assembly failures remain recorded: an invalid provisional-family
partition, excess memory from duplicate live JSON trees, and scripted prediction
event/center disagreement in unknown reference spans. Repairs use development
partition with reference-only exposure, free construction trees before scoring,
and expand each script's center cells from its own events. No reference byte,
event endpoint, source, scoring threshold or resource bound changes. Final runs
take 17458/17312 ms and at most 122,494,976 sampled private bytes, within the
60-second/128-MiB/32-MiB limits, with zero leaks. Forced termination in the failed
memory run has no leak verdict. Helper failures remain zero; no live handles.

All five criteria are accepted; the consecutive no-criterion-closure count is
**zero**. Move and credit: +1 NS-3 point / +0.25 overall, **39% NS-3, 63.15%
overall, 37 open / 13 DONE, 50 tasks and 96 acyclic dependency edges**, confirmed
by the completion-document graph check. No new task or duplicate credit was introduced.
Final documentation QA passes: links, preserved criteria, accounting, evidence,
privacy and whitespace checks are complete; documentation is ready for publication.
Remaining external crossings, unison, quiet-part ownership and broader reference
coverage stay with actual role-learning/independent acceptance requirements.

The previous goal turn made progress by preparing this bounded source/reference
path; the intervening Athena check confirmed the already-published merged pin.
Continue the same NS-5 prerequisite path: parts_02 is still blocked by
[notes_03](TODO/NS-3_notes_03.md), which requires recorded identity and
presence/boundaries. Reference preparation no longer blocks it. Before another
note experiment, reassess the failed observation families and declare a genuinely
discriminating observation, fixed controls and stop decision. Preserve untouched
phrase material. Do not return to the stopped source registration/tail studies.

## Previous checkpoint — combined references and annotation limits — 2026-09-21

The preceding goal turn made progress at `1faaa670`: batch 25 closed AC1 of
[parts_01](TODO/DONE/NS-3_parts_01.md). Exact revision CI run 35639071198 is verified
successful. Continue the same NS-5 prerequisite path. Batch 26 starts with zero
consecutive batches without a criterion closure; it targets AC2/5 with reserved
acoustic references and one runnable two-family packet.

The reused spectral exporter/viewer pass checked Win64 controls, exact replay,
resource limits and rejection preservation. Primary reference-only review supports
one reserved source-local bass center. Chordal registration, broad stabs and
earlier lead-note tails prevent complete acoustic labels at the frozen markers.
Those states remain unknown. No model is run or selected; symbolic gates do not
become acoustic truth. One predeclared marker was off-grid and remains unavailable
without replacement. The [packet consumer guide](PART-REFERENCE-PACKET.md) and
current scenario ledger keep all contributors and missing coverage visible.

The first reserved assembly submission fails because two silent excerpts share
the same encoded WAV digest. The ledger incorrectly treated the two retained
files as distinct hash nodes; failure also exposed exception cleanup leaks.
The repair deduplicates content identities while retaining every source file and
frees rejected parents/partial ledgers. Labels, source policy and scoring are
unchanged. The failed partial output and logs remain preserved. Root component
failure count is one; the combined-container helper has zero failures.

Final QA accepts **AC5**. The repaired reserved packet has 108 files; the combined
container has 217 files / 29,908,178 bytes and reproduces every byte. All sixteen
maintained CLI cases pass after relocation, with reports unchanged apart from
the established terminal line ending. Preservation and seven malformed-input
controls pass; successful and rejection runs have zero leaks. The evidence and
full source/policy identities are in `build/qa-batch-26/report.txt`.

AC1/3/4/5 are closed; **AC2 remains partial**. The consecutive no-criterion-closure
count stays **zero** because AC5 closes. No task move or credit is claimed:
**62.90%, 38 open / 12 DONE, 96 dependency edges**. This source investigation
now stops. Further
registration/tail/silence variants cannot provide trustworthy missing labels.
The next annotation action must use a source with curator-reviewed acoustic
notes, subject to verified access, provenance, clock and local function review.

A bounded feasibility review selects one short recorded ensemble with
curator-corrected acoustic notes. The original
[URMP deposit](https://datadryad.org/dataset/doi:10.5061/dryad.ng3r749)
resolves source terms through CC0, while original selective delivery remains
unverified. A [521-MB prepared archive](https://zenodo.org/records/10009959)
responds to an availability check; its conversion and annotation-clock provenance
must be verified before labels are used. No payload was acquired and existing
held-out phrase material was not inspected. This changes the next annotation
action without changing the task's scope, credit or numerical gates.

Final documentation QA passes: 2710 local links in 133 documents, the 50-task/
96-edge acyclic graph and unchanged credit accounting reconcile. The five-document
scope, evidence identities, privacy and whitespace checks pass; ready for publication.

## Previous checkpoint — local roles and sparse acoustic references — 2026-09-21

The preceding goal turn made progress at `918de567`, publishing evaluation-family
preparation and the merged Athena pin. Its exact revision CI run 35637230017 is
verified successful. Continue [parts_01](TODO/DONE/NS-3_parts_01.md) on the NS-5
prerequisite path; no completed extraction or infrastructure work is reopened.

Batch 25 [reference review](PART-EVALUATION.md#reviewed-development-centers-and-reserved-worksheet--2026-09-21)
supplies sparse source-local chordal/lead center sets from the existing full
spectral views and fixed six anchors. The current center-only contract preserves
800 positions, with two known triad centers and four known lead centers; every
other position remains unknown. These are primary reference annotations, not
invented note intervals, full-mixture ownership or learner predictions.

Final QA accepts the corrected 101-file packet, exact replay, preservation and
relocated native CLI scoring, all with zero leaks. The first root submission
was rejected because its center policy inherited an inapplicable event threshold;
the existing schema requires that field to be zero. The correction changes no
center gate or old interval gate. Root blocking history remains one, helper zero;
the failed output and logs remain preserved. Annotation meaning is reviewed
separately from the scripted copy/omit results, whose accuracy/independence
verdicts all stay false. Detailed identities and budgets are in topic evidence
and `build/qa-batch-25/`; no runtime handles remain.

The reserved worksheet also passes controls, exact 37-file replay and rejection
preservation: all ten sources plus mix, raw MIDI/performance evidence and complete
amplitude grids retain reference-only exposure. Primary review supports the
local S00 thematic lead, S01 bass underpinning and S02/S08 harmonic accompaniment,
using musical relationships and actual source presence. Instrument categories
are not role labels; other contributors and all reserved acoustic notes/timing
remain unknown. No listening or independent reviewer consensus is asserted.

Final QA accepts **AC1** for both bound constructions, notices, clocks/gains and
reviewed local functions. AC3/4 retain prior acceptance. AC2/5 still require useful
reserved acoustic references, explicit scenario coverage and the combined native
packet. The consecutive no-criterion-closure count resets from one to **zero**
because AC1 closes, not because an exporter or repair passes. Next complete that
remaining reference/packet deliverable with existing tools; no further source
construction, family-identity, renderer-history or threshold investigation.

The full task stays open: **62.90%, 38 open / 12 DONE, 96 dependency edges**.
No partial task credit, model change or new format is claimed.
Final documentation QA passes: 2710 local links, the 50-task/96-edge acyclic
graph and credit accounting reconcile; source/policy identities are unchanged.
The four-document scope is checked and ready for branch publication.

## Previous checkpoint — evaluation-family preparation and Athena update — 2026-09-21

The preceding goal turn made progress at `759b047`: the development packet is
reproducible and AC3/4 of [parts_01](TODO/DONE/NS-3_parts_01.md) are accepted. Its exact
revision CI run 35635811634 is now verified successful.

Batch 24 advances AC1/5 with the reserved family's complete contributor binding
and fixed-gain exact-sum mixture. It starts with zero consecutive batches without
criterion closure. The source inventory and the maintained preparation operator
are separate components for paired final QA. Frozen bounds and stop conditions
are in `build/role-evaluation-reference/POLICY.md`; reference-only exposure is
required. Reuse the existing waveform path and integer oracle, preserve all ten
present contributors, and record absent metadata stems rather than trusting stale
rendering flags. This preparation does not itself complete role annotations.

The user also authorized adopting the merged Athena update. Upstream's default
branch is `main`; the pin moves from `909336d` to
`b8cdb5b3c36d0b3670a4b722d98d905a2cb78de3`, merge of taskflow-2. The fetched
change contains shared progress checkpoints, scope-preserving task splits and
adoption templates. PROJECT.md and the local task-flow link adopt that revision;
dated build/checkpoint pins retain their historical identities. No dependency
source is edited. Include the pin and affected-document review in final batch QA.

The source binding passes final QA: all ten sorted WAV/MIDI pairs match the
selected archive roster, S10/S11 absence is explicit, and both fresh 7614-byte
bindings are identical. Existing/outside output rejection preserves prior files.
Runs take 2473/2024 ms, at most 2969600 sampled private bytes, with zero leaks.
SHA256 is `e41e0ce9a688f8cc2773f1dd6f67a06f73447eb3937a47346a66585249c6d2ce`;
evidence remains under `build/role-evaluation-reference/` and `build/qa-batch-24/`.
The Athena checkout is clean, matches upstream main and has both expected merge
parents; all 284 shared-document links pass.

Final checked stable Win64 preparation also passes: every scaled source sample
matches the integer oracle and the stored mix equals the exact sum of all ten
derived stems. The reserved source retains 3046087 mono frames at 16000 Hz and
zero offset, with mix peak 1804 PCM16 LSB. Both 15-file packets replay exactly,
including manifest SHA256
`d7c3f42fc42863bc239401f3cdab02ba913052a4c0fd7c58d6a8326d4a023654`.
Evaluation takes 11307/11388 ms, at most 3522560 sampled private bytes; all runs
have zero leaks. The development regression takes 14451 ms and reproduces all
eleven historical WAVs byte-for-byte. Identity/exposure controls and existing,
wrong-binding-hash and outside-output rejections pass with preservation. No
audio algorithm, gain, offset or scoring gate changes.

The [maintained operator](PART-PREPARATION.md) preserves the exact exposure,
binds the accepted family decision and uses one current `derived-stem-mixture`
manifest kind. Scoped family qualification remains separate from unknown training
overlap, unverified broad independence and missing roles/acoustic timing. Full
commands, artifact identities and resource observations are in `build/qa-batch-24/`.
Both component submission-failure counters remain zero; no runtime handles remain.
Final documentation QA passes: source/policy identities, adopted dependency pin, local links, task accounting, privacy, whitespace and nine-path scope are checked. This batch is ready for publication.

AC1/2/5 remain partial: the second family's source construction is ready, but
reviewed local roles, useful chordal/lead acoustic reference intervals and the
complete scoring packet still need delivery. This batch closes no additional
whole criterion, so the consecutive no-criterion-closure count is **one**.
Next use the existing reference worksheet/builder for those concrete annotations;
stop preparation/identity investigation. If that next batch closes no criterion,
apply the required reassessment before another batch. No task move or percentage
change: **62.90%, 38 open / 12 DONE, 96 dependency edges**.

## Previous checkpoint — assembled development cases and family review — 2026-09-21

The previous goal turn made progress by publishing the generalized Athena
task-flow checkpoint on its requested branch. Resume the existing first assembly
batch after the preparation-task reassessment; the side task did not reset that
count. Pythian's preceding `77033ff` CI run 35632989540 is verified successful.

Final batch-23 QA accepts the [assembled development cases](PART-EVALUATION.md#assembled-external-development-cases--2026-09-21):
all ten stems and their mix, complete notices, contributor/scenario inventory,
the reviewed bass interval and explicit uncertainty travel together. The native
operator reproduces scoring after relocation outside the repository. The copied
event scores 143 correct centers and one onset/full-note pair; omission scores
143 misses; the same contribution in an unknown mixture remains unscorable.
All independent/accuracy verdicts remain false because predictions are scripted
from references and the references are incomplete. This closes AC4's application
of the frozen policy to the assembled cases, without learner or task credit.

Both fresh packets reproduce every byte; rejection preserves prior artifacts.
Assembly takes 6147/5611 ms, at most 65728512 sampled private bytes, with zero
leaks. Relocated CLI report content matches; its existing terminal CRLF is the
only stdout difference. The separate fixed family screen also passes controls,
replay and preservation: no complete or 32-onset matches across the two scores.
Its negative finding alone is not a family qualification. Full terminal results,
commands and source/policy identities remain in `build/qa-batch-23/`.

The source-work review resolves the reserved score's missing title through its
exact publisher filename key and corroborating matched-recording metadata.
The development score's embedded title and original filename agree, but its
matched-recording association conflicts. Preserve that conflict, keep both
development associations ineligible for evaluation and base source identity on
the actual original score. The separate decision, evidence hashes and frozen
membership/exposure are in `build/role-family-identity/DECISION.md`. Final QA
verifies the exact source hashes/keys, both lookup rows, full notice and conflict
restriction and accepts AC3 for these two families. The [qualified split](PART-EVALUATION.md#qualified-initial-recording-families--2026-09-21)
does not establish model-training independence or qualify other archive material.

This first assembly batch closes AC3 and AC4, so consecutive batches without
criterion closure return to zero. AC1/2/5 remain partial.
Next deliverable: prepare the qualified evaluation family's full contributor
binding and derived mixture under the existing fixed gain/clock rules, preserving
reference-only exposure, then complete useful role annotations for both families.
The maintained preparation operator currently admits only the development source;
extend that explicit provenance contract before running evaluation preparation.
Do not restart digital-support, renderer-history or duplicate-threshold studies.

Final documentation QA passes: claims, local links, task graph/accounting, privacy, whitespace and six-file publication scope are checked. This checkpoint is ready for publication.

No task moves in this batch: **62.90%, 38 open / 12 DONE, 96 dependency edges**.
Both new implementation submission-failure counters remain zero; the historical
worksheet-summary failure remains one. No model, musical gate or format changes.

## Previous checkpoint — task-size reassessment and first external interval — 2026-09-21

The previous goal checkpoint made progress with source correspondence at
`711ab4c`; its exact-head CI run 35629646771 is now verified successful. However,
the last two diagnostic batches established acoustic support and source mapping
without closing an original parts_01 acceptance criterion. The user's task-flow
review correctly identified the oversized task and risk of endless investigation.

Apply the new [mandatory checkpoint](TASKFLOW.MD#task-size-and-investigation-stop-points)
immediately. The [scope reconciliation](MILESTONES.md#mixture-preparation-task-split)
splits the existing two-point preparation scope into maintained measurement/control
delivery (parts_04, one NS-3 point) and qualified external references (parts_01,
one point). Every original criterion retains an owner, and inference still depends
on both through the prerequisite chain. The split alone earns no credit. Final
QA verifies all five maintained-deliverable criteria and twelve current tested
identities; [parts_04 is moved to DONE](TODO/DONE/NS-3_parts_04.md). Reuse of the
applicable checked-target results avoids redundant suites. NS-3 moves 37% → 38%;
overall **62.65 + 0.25 = 62.90%**. The catalog now has **50 tasks: 38 open,
12 DONE**, with **96 dependency edges** and unchanged total scope allocation.

The [bounded support investigation](PART-EVALUATION.md#first-external-bass-reference--2026-09-21)
is finished. Its fixed native pass retains all seven bass events and finds one
isolated component. Primary acoustic/function review admits note 38 on
`[48047,70950)` in the isolated source. Other events retain joined/edge uncertainty.
The unchanged native builder exports a complete 800-center reference with one
known event, three source-local rest regions and two unknown regions. This is
usable external annotation evidence, not complete ensemble or learner acceptance.

Final QA passes support controls, exact report replay, rejection preservation
and reference-builder replay with zero leaks. The report is 22028 bytes and the
reference 77851 bytes. Full hashes, commands, scope and all-seven decisions are in
`build/qa-batch-22/` and `build/role-reference-draft/`. No runtime handles remain.
Boundary/checker helper submission failures are zero; historical summary remains
one. No algorithm, model, musical gate or source window changed.

Next deliverable: assemble the development external case/coverage inventory from
existing annotations and explicit unknowns, then qualify the reserved family
under a frozen reference-only identity/duplicate review and finish packet assembly.
Do not continue digital-silence variants or historical-renderer reconstruction.
Record criteria closed at every batch handoff; two batches without a criterion
closing require a changed approach or deliverable split before more investigation.

## Previous checkpoint — verified bass source correspondence — 2026-09-21

The preceding goal turn made progress by publishing fixed acoustic support and
register findings at `41b1500`. Continue [NS-3_parts_01](TODO/DONE/NS-3_parts_01.md) on the
NS-5 prerequisite path. The [original-to-trigger comparison](PART-EVALUATION.md#original-to-trigger-bass-correspondence--2026-09-21)
now passes checked stable Win64 controls, exact replay and rejection preservation
without leaks. All seven scoped bass events match exact rational onset/end and
velocity before pitch comparison. Program-based track/channel selection is unique;
no pitch fitness, fitted time tolerance or new waveform observation is involved.

Original pitches 38/38/38/40/43/31/31 map to 50/50/50/52/55/55/55. All agree
with range-fold 35..79 followed by +12, whereas a simple +12 fails the final two.
The observed correspondence is compatible with pinned upstream source, not proof
of its exact historical deployment or preset behavior. The roughly 98-Hz acoustic
family occurs with both original 43 and original 31, so copying either source-key
column wholesale would be unsound. The [reference contract](PART-REFERENCE.md#pitch-identity-in-an-acoustic-reference)
now makes symbolic intent, renderer trigger and acoustic note meaning explicit
without changing the current format, scoring gates or task requirements.

Native report runs take 483/487 ms, at most 5566464 sampled private bytes, and
emit identical 17490-byte reports under unchanged 10-second/64-MiB/256-KiB limits.
The report binds both source files, retained performance data, exact pitch pairs
and code/policy identities. New comparison failures remain zero; historical
summary failure count remains one. Complete evidence is in `build/qa-batch-21/`;
all runtime handles are terminal. No external code was executed or installed.

Next use the source-specific correspondence with the existing waveform evidence
to resolve supported acoustic reference notes and boundaries. Preserve source
mapping in provenance; do not apply a blanket inverse or transfer the bass rule
to organ registration. Other contributors, complete role pitch sets, external
scenario coverage and evaluation-family qualification remain open under this
task. The prospective interpretation in `build/role-register-source/REFERENCE-DECISION.md`
was frozen before the comparison. Final documentation QA passes: correspondence claims, 2663 local links, task graph/accounting, privacy, whitespace and five-file scope are checked. This checkpoint is ready for publication under the same QA batch.

Completion stays **62.65%, 38 open / 11 DONE, 95 dependency edges**. The source
mapping finding changes the annotation decision, not accepted learner completion.

## Previous checkpoint — fixed acoustic support and register findings — 2026-09-21

The preceding goal turn made progress by publishing the mixture policy and fixed
worksheet review at `b826576`. Continue [NS-3_parts_01](TODO/DONE/NS-3_parts_01.md) on the
NS-5 prerequisite path. Its new [acoustic review](PART-EVALUATION.md#fixed-acoustic-support-review--2026-09-21)
observes only the already fixed first eight seconds of four development stems.
The owned WAV/FFT primitives produce complete window powers; a separate native
view preserves global per-stem scaling, window support and source identities.

Final checked Win64 controls, full export/view replay and rejection preservation
pass with zero leaks. Export maximum: 6337 ms, 5992448 sampled private bytes,
50820060 output bytes. View maximum: 4312 ms, 29396992 sampled private bytes,
7214319 output bytes. Both remain inside frozen 30-second/128-MiB limits and
their respective output budgets. The new helper diagnostic has zero blocking
submissions; the earlier worksheet summary retains one historical failure.
Sources, hashes, commands and terminal results are in `build/qa-batch-20/`.

Primary review of all four views and predeclared numerical anchors supports
S03 bass and S02/S05 chordal source functions over `[52000,112000)`. It does not
establish complete role pitch sets, independent annotation or exact event timing.
S03's harmonic spacing is consistent with roughly 73/98 Hz beneath nominal keys
50/55; S05 also retains sub-octave components relative to its keys. The actual
rendering/register cause is unresolved. S00 retains spectral energy after key-off
and performance uncertainty. These are concrete reasons to reject direct MIDI
labels as acoustic truth, not permission for a blanket octave correction.

Next resolve reference register/registration semantics and acoustic boundaries on
this evidence, preserving key identity, observed components and uncertainty.
Other contributors, external scenario coverage and evaluation-family qualification
remain open under the existing task. Do not run another generic inventory, tune a
learner against these unresolved labels or repeat stopped register experiments.
Private review rationale is in `build/role-support-view/ANNOTATION.md`; the prior
step design remains in `build/role-review/NEXT-ANNOTATION.md` for provenance.
Final documentation QA passes: retained spectral claims, 2654 local links, task graph/accounting, privacy, whitespace and four-file scope are checked. This documentation checkpoint is ready for publication under the same QA batch.

Completion stays **62.65%, 38 open / 11 DONE, 95 dependency edges**. No new task,
scope reduction, dependency, threshold or completion credit is introduced.

## Previous checkpoint — mixture policy and fixed worksheet review — 2026-09-21

The prior implementation goal turn made progress: the reviewed-reference builder
and fixed worksheet were published at `60c419e`. The intervening configuration
check changed no project capability. Continue [NS-3_parts_01](TODO/DONE/NS-3_parts_01.md)
on the NS-5 prerequisite path.

The [mixture policy](PART-MIXTURE-POLICY.md) now freezes initial scope, required
scenarios, role/acoustic annotation rules and existing per-role gates. QA accepts
the policy; preparation, uncertain challenges and independent learner admission
remain separate. Linked task descriptions identify the final independent-admission
integration owner without changing prerequisites or credit.

The [fixed worksheet review](PART-EVALUATION.md#fixed-worksheet-review--2026-09-21)
now passes checked native controls, exact report replay and rejection/preservation
QA. It consumes only the accepted ten symbolic and ten amplitude documents and
preserves all first-eight-second gates. The 20149-byte report covers 343 retained
gates and 1521 raw events; maximum measured cost is 3621 ms and 15028224 bytes
sampled private memory under the unchanged 5-second/64-MiB/256-KiB limits.

One blocking implementation submission found signed-32-bit narrowing in a `Min`
call on rational time. The helper's first repair uses an explicit 64-bit comparison
and exercises the actual summary above 2^31. The second submission passes with
zero leaks; the historical failure count is one and ownership does not transfer.
Commands, source/input/policy identities and preserved failure evidence remain
under `build/qa-batch-19/`. Runtime handles are terminal.

Primary score-context review identifies bass/chordal/thematic candidates through
cross-stem relationships, while actual role/acoustic annotations remain unknown.
One stem is digitally silent, known gates do not supply a same-pitch overlap
scenario, and retained bends prevent assuming nominal keys are constant sounding
pitches. No hearing, external role accuracy or family independence is inferred.
Next examine acoustic support on the same fixed passage, resolve defensible
annotations with explicit uncertainty and map external scenario gaps; do not
start another generic inventory or use model predictions as reference truth.
The original mix's failed construction and provisional evaluation family remain
unchanged. Final documentation, evidence meaning, links, accounting, privacy and
publication scope pass review. This batch is ready for normal publication; its
exact revision is reported separately.

Completion stays **62.65%, 38 open / 11 DONE, 95 dependency edges**. This evidence
advances the open preparation task; no completed learner or genre style is claimed.

## Previous checkpoint — worksheet and reviewed-reference construction — 2026-09-21

The preceding goal turn made progress by publishing verified derived preparation
at `f8e24d2`; its
[native CI passes](https://github.com/mr-highball/pythian/actions/runs/35622573252).
Continue [NS-3_parts_01](TODO/DONE/NS-3_parts_01.md) on the NS-5 prerequisite path.

The [reviewed-reference builder](PART-REFERENCE.md) now converts explicitly declared
intervals/uncertainty into a complete regular center grid through a portable API
and the maintained evaluation CLI. Checked stable Win32/Win64 builder and complete
file fixtures pass with zero leaks. A generated ten-center reference retains two
lead and six chordal matches through the current timing scorer. Identity, clock,
grid, region, ownership-ID and preservation boundaries pass; no role or acoustic
labels are inferred by construction.

The [fixed 30-second worksheet](PART-EVALUATION.md#development-annotation-worksheet--2026-09-21)
also passes checked Win64 controls, two exports and rejection/preservation QA.
All 36 files / 13302611 bytes replay, including the manifest. Eleven excerpts
retain a separate 250-ms context; complete 10-ms amplitude grids and ten raw
MIDI/gate documents retain original source coordinates. Full bound MIDI decoding
visits 12139 events without encountering an unsupported mapping. All role and
acoustic labels remain unknown. Maximum observed export cost is 12099 ms and
14241792 bytes sampled private memory, inside frozen budgets. Sources, exact
commands, identities and outcomes are retained in `build/qa-batch-18/`.

Helper blocking failures remain zero; runtime handles are terminal. Final
documentation, frozen identities, links, accounting, privacy and publication scope
pass review. This increment is ready for normal publication; its exact revision
is reported separately. Next inspect
the fixed waveform/symbolic worksheet for defensible functions and acoustic
support; do not use amplitude, instrument labels or key gates alone as note truth.
An isolated native evidence-summary diagnostic is being prepared under ignored
`build/role-review/`, compilation only until another ready QA item. Freeze any
reviewed annotations before predictions; retain uncertainty and absent coverage.

The original mix's failed summation and provisional evaluation-family status
remain unchanged. Completion stays **62.65%, 38 open / 11 DONE, 95 dependency edges**.
Reference construction/export is a delivered component of the open task, not an
accepted attributed-mixture learner or a completed genre style.

## Previous checkpoint — derived reference preparation — 2026-09-21

The preceding goal turn made progress by publishing maintained role controls and
file-bound interval timing at `eb2b221`; its
[native CI passes](https://github.com/mr-highball/pythian/actions/runs/35620690813).
Continue [NS-3_parts_01](TODO/DONE/NS-3_parts_01.md) on the NS-5 prerequisite path.

The maintained [derived preparation operator](PART-PREPARATION.md) now constructs
separately identified external development stems/mix. Fixed 1/16 scaling followed
by explicit PCM16 quantization preserves sample coordinates and guarantees
headroom; the mix is the exact sum of the stored derived stems. Checked stable
Win32/Win64 arithmetic and complete Win64 preparation QA pass with zero leaks.
Both 3864916-frame runs reproduce all 14 files and their manifest exactly;
the 85060427-byte packet stays within 180 seconds/256 MiB/1 GiB at 14620/14549 ms
and at most 3502080 bytes sampled private memory. Negative identity, overwrite,
count and path controls preserve accepted output. Real-data evidence is mono;
stereo/geometry branches were source-reviewed. Full results, identities and
limits are in [part evaluation](PART-EVALUATION.md#derived-external-development-packet--2026-09-21)
and `build/qa-batch-17/`. The original publisher mix's failed check is unchanged.

The prospective family ledger also passes bounded native QA. Track00001 remains
development and Track00002 remains reserved provisionally: different declared
identities/score hashes exclude exact collisions without establishing unrelated
arrangements or training disjointness. No new evaluation note/audio exposure
occurs. Helper blocking submissions remain zero. Runtime handles are terminal;
final documentation, frozen identities, links, accounting, privacy and publication
scope pass review. This increment is ready for normal publication; its exact
revision is reported separately.

Next prepare one fixed 30-second development annotation worksheet across the
derived stems/mix, preserving score gates/controllers separately from acoustic
evidence and initially unknown musical functions. Its protocol and isolated
implementation work are under ignored `build/role-annotation/`; final execution
waits for another ready QA item. Source role/acoustic annotations, broader family
qualification and scenario thresholds still govern task acceptance.
Completion remains **62.65%, 38 open / 11 DONE, 95 dependency edges**. No task move,
new credit or independent inference/style verdict follows from preparation.

## Previous checkpoint — maintained role packet and file-bound timing — 2026-09-21

The preceding goal turn made progress by publishing the interval scorer and
authored mixture controls at `2a649c9`; its
[native CI passes](https://github.com/mr-highball/pythian/actions/runs/35618895403).
Continue [NS-3_parts_01](TODO/DONE/NS-3_parts_01.md) on the NS-5 prerequisite path.

The [maintained packet operator](PART-EVALUATION.md#maintained-packet-operator)
now reproduces the accepted construction from tracked Pascal source and two
tracked policies, without private assets. Final checked Win64 controls, two fresh
generations and overwrite rejection pass with zero leaks. All five WAVs match
the accepted originals; all 34 nonmanifest artifacts replay, and rejection
preserves all 35 files. The packet stays within the frozen 30-second/256-MiB/8-MiB
bounds at 5396/5442 ms, at most 28798976 bytes sampled private memory and
3744215 output bytes. Source-derived predictions retain shared authored ancestry.

The [part-notes file metric](OVERLAPPING-NOTES.md#file-bound-role-timing) combines
per-role center/ownership and interval timing gates, checking that events and
center pitch sets agree. Reference regions, unique event IDs across roles, clocks
and complete role lists are enforced. A lowered caller matching budget lets the
operator enforce one combined limit across roles while preserving the core's
default. Final checked stable Win32/Win64 interval and complete file fixtures
pass with zero leaks; both CLI builds pass. A damaged duration fails despite
perfect center/onset scores, and contradictory/uncertain inputs retain their
declared behavior. Existing phrase and prediction-ancestry checks remain covered.

Commands, identities, source review, report replay and packet comparison evidence
remain in `build/qa-batch-16/`. No runtime handle remains live; helper blocking
failures stay zero. Final documentation, frozen source identities, links, task
accounting, privacy and publication scope pass review. This increment is ready
for normal publication; its exact revision is reported separately.
Completion remains **62.65%, 38 open / 11 DONE**. Packet delivery and timing
integration are delivered components; representative frozen families and external
preparation/role/acoustic-timing qualification remain open. The initial external
sum failure is preserved. No new allocation, task closure, independent mixture
acceptance or genre-style credit is claimed.

## Previous checkpoint — overlapping-note timing and authored mixture controls — 2026-09-21

The previous goal turn made progress: the role-set evaluator and source preflight
are published at `f5d520b`, whose
[native CI passes](https://github.com/mr-highball/pythian/actions/runs/35616527307).
Continue the same [attributed-mixture task](TODO/DONE/NS-3_parts_01.md), a prerequisite
of NS-5's semantic style goal. The external bundle's fixed preparation failure
remains unchanged; no offset/gain correction is fitted to pass it.

The maintained [overlapping-note API](OVERLAPPING-NOTES.md) now implements
unrestricted one-to-one matching per declared role, with separate optimal
onset/full-note assignments, exact rational timing thresholds and explicit
uncertain/censored reference accounting. Existing ordered monophonic scoring is
unchanged. Its tiny independent assignment oracle and boundary fixture pass final
checked stable Win32/Win64 QA with zero leaks, including count/cost/pair consistency,
permutation replay, repeated-note multiplicity and uncertainty/rest rejection.

A separately authored twelve-second control packet declares four musical roles
before rendering. It quantizes the stems first and builds the mix from their
stored integer samples, allowing exact gain/offset reconstruction checks. Native
controls include chords, crossings, repeated same-pitch overlap, rests, a quiet
masked part and withheld ownership, plus per-role event timing. Score-derived
predictions retain their shared authored ancestry and do not represent inference.
Final checked Win64 controls, two fresh packet runs and overwrite rejection pass
with zero leaks. All 192000 frames reconstruct exactly, and all 34 nonmanifest
artifacts replay byte-for-byte; rejection preserves all 35 files. The packet is
3744215 bytes. Runs take 5401/5429 ms with at most 28762112 bytes sampled private
memory, within frozen budgets. Exact per-role event counts are 4/9/5/3; a reordered
lead preserves all five identities, while a damaged endpoint separates onset and
full-note matches as declared. Its code, frozen policies and instructions remain
under `build/role-controls/`; detailed [controlled evidence](PART-EVALUATION.md#authored-stem-mix-controls--2026-09-21)
links the native observations and limitations.

Both implementation increments pass QA; source review, commands, artifact hashes
and resource logs remain in `build/qa-batch-15/`. No runtime handle remains live;
helper blocking failures stay zero. Final documentation, source identities, links,
task accounting, privacy and publication scope pass review. This increment is ready
for normal publication; its exact revision is reported separately.
Completion remains **62.65%, 38 open /
11 DONE** until all task criteria pass. External preparation/role evidence,
representative frozen groups and public packet delivery remain open; this work
does not accept mixture learning or genre style. No new task allocation is needed
for these existing criteria. No task is moved to DONE.

## Previous checkpoint — simultaneous role-set evaluation — 2026-09-21

The preceding diagnostic batch is published at `980bd27`; its
[native CI passes](https://github.com/mr-highball/pythian/actions/runs/35613255915).
That goal turn made progress by rejecting two measured representations; neither
became an admitted musical provider. The current increment follows the ready
[attributed-mixture prerequisite](TODO/DONE/NS-3_parts_01.md) of NS-5 layered styles.

The new portable [role-set scorer](PART-EVALUATION.md) measures simultaneous
notes, uncertainty, per-role coverage/precision, ownership leakage and explicitly
annotated crossing endpoints. The existing file operator binds those diagnostics
to actual source/document bytes and exposure ancestry. It rejects a primary
acceptance claim; timing and physical ownership require further evidence. Final
checked stable Win32/Win64 core and complete file fixtures pass with zero leaks;
both operator builds pass. Existing phrase and prediction-ancestry controls
remain covered. An initial QA command omitted the required output directory;
its usage failure is preserved separately and the corrected invocation passes.
This was orchestration error, not an implementation failure.

The selected external synthetic development group has ten stored stem/MIDI
pairs and a mix. Its publisher archive checksum is verified and only that group's
payload was extracted. Metadata falsely marks all present pairs as unsaved;
the binding retains this contradiction, absent source entry and unknown musical
roles. Native preflight verifies mono 16-kHz PCM16 geometry over all 3864916
frames and raw MIDI counters, but fixed unity-gain/zero-offset summation fails
preparation qualification: peak 13 LSB, RMS 5.7881281944898015 LSB and 433 frames
above the declared 11-LSB candidate bound. No gain/offset fit or acoustic timing
claim follows. Controls, full traversal and wrong-hash/existing-output rejection
pass with zero leaks, within 180 seconds/256 MiB. The valid pass takes 4257 ms
with 3874816 bytes sampled private memory. Assets and complete notices stay in
`build/role-reference/`; report SHA256 is
`bd47eb1bc7c647939ab5e5410d310cfa62f08e79edd2caac41a22ab66fea0e90`.
Commands, source review, hashes and per-target results remain in
`build/qa-batch-14/report.txt`. No runtime handle remains live.

No task closes or credit changes: **62.65%, 38 open / 11 DONE**. Note/context
research remains open, with rejected families stopped. This implementation does
not establish learned mixture roles or genre-level generation. Next complete
per-role interval timing, representative controlled mixture coverage and external
preparation/role evidence under the same task. Helper blocking failures remain
zero for this assignment; historical counters are unchanged. Final documentation,
source-identity, link, task-accounting, privacy and publication-scope checks pass.
This validated increment is ready for normal publication; its exact revision is
reported separately. The dedicated review cycle is inactive.

## Previous checkpoint — contour and harmonic feasibility rejected — 2026-09-21

The preceding six-document batch is published at `477196c`; its
[native CI passes](https://github.com/mr-highball/pythian/actions/runs/35611388607).
The next batch investigates two previously untested representations while reusing
existing sources. An inventory first rejects a redundant admission ledger: prior
head diagnostics and the contextual decoder already explain that partitioning
changes segment survival without changing raw note/RMS admission.

The [cached contour diagnostic](PHRASE-EVALUATION.md#cached-contour-support-does-not-recover-both-short-notes--2026-09-21)
passes final QA and fails common-short-note feasibility. MIDI 33 wins none of
three raw rows or three scoring centers inside the 30-ms 55-Hz note; the 440-Hz
note wins, but its pitch also wins all centers in the true repeated-note gap.
Stop the contour fallback without new model execution or a recorded comparison.
The [harmonic-dictionary study](TONAL.md#harmonic-dictionary-feasibility) also
stops at controls: 31/72 fail after numerical correction. Both simultaneous-note
controls pass, but spectral-shape variation yields false class weight and a
missing-fundamental octave error. Do not adopt a correct top coefficient as an
accurate note distribution or sweep dictionary weights to pass these controls.

QA exposed Single narrowing in the primary-owned solver's overloaded clamps.
Explicit Double branches and a nonbinary exact-update regression correct it;
compiler assembly confirms the repair. Preserve the original report and its
53 mixed numerical/scientific failures; the corrected 31-failure result is the
accepted interpretation. Only the affected suite was rerun. Both diagnostics,
their controls and output-preservation checks now finish within budgets with
zero leaks. Commands, hashes, source review and resource results are retained in
`build/qa-batch-13/report.txt`. No process remains live. Final documentation
checks pass: native evidence, links, task accounting, privacy and the six-document
scope are verified. This batch is ready for normal publication; its exact revision
is reported separately.

The originating NS-5 corpus/style goal remains active through its note/context
and learning prerequisites. Next define source observations that distinguish
harmonic-envelope changes from genuinely different notes while retaining the
short/quiet/gap controls. The current evidence selects no replacement provider;
this is research work remaining, not an external scheduling blocker. Independent
evaluation material remains untouched. No task closes or credit changes:
**62.65%, 38 open / 11 DONE**. The primary-owned repair does not increment delegated
failure counters, and historical counters remain intact.

## Previous checkpoint — exact trace and key-decision audit accepted — 2026-09-21

The preceding six-document batch is published at `ff2e025`; its
[native CI passes](https://github.com/mr-highball/pythian/actions/runs/35608515576).
The next two-item diagnostic batch passes final source/runtime QA. The
[exact availability replay](PHRASE-EVALUATION.md#exact-availability-trace-replay--2026-09-21)
reproduces all five original outputs for all 96 flute and 87 violin events.
Previously unresolved measurements exit at the first- or second-window
phase-support checks. This identifies the executed branch without establishing
a physical cause. All eleven flute octave-error events still fail the lower
guard, so repairing only upper availability cannot rescue the proposal. Keep
the predictive and contingent envelope corrections stopped.

The [key-decision audit](TONAL.md#rejected-profile-decision-audit) exactly replays
the rejected profile scores and reconciles every labelled-frame transition.
Both recordings lose correct predictions in fully labelled constant contexts;
the errors include fifth-related and more distant alternatives. Stop profile
variations. A new key proposal needs temporal and frequency evidence that can
distinguish tonic from sustained dominant activity; the audit does not establish
which acoustic source caused the observed class contributions.

Checked stable Win64 controls, original-source replays and the key audit finish
with zero leaks and within declared resource bounds. Trace output identities,
exact fit-work totals, sampled private memory and the key audit's separately
bounded explanatory contribution residuals are recorded in the linked topic
pages and `build/qa-batch-12/report.txt`. No runtime process remains live.
Final documentation checks pass: native evidence, links, task accounting, privacy
and the six-document scope are verified. This batch is ready for normal
publication; its exact revision is reported separately.

Return to NS-5 through its admitted-note/learning prerequisite. Note identity
requires independent discriminating evidence; note presence is separately open.
Before another presence experiment, reconcile the existing separate-head,
event-context and short-note evidence and define the next observable result.
Do not repeat the rejected direct decoder or mistake model execution for note
admission. No new held-out material, maintained inference change, task closure or
credit follows from these diagnostics: **62.65%, 38 open / 11 DONE**. Historical
failed-submission counters remain unchanged.

## Previous checkpoint — fixed profile rejected; availability diagnostic passes — 2026-09-21

The preceding nine-document batch is published at `0785186`; its
[native CI passes](https://github.com/mr-highball/pythian/actions/runs/35607192822).
The next two-item batch passes final runtime/source QA without a blocking
implementation defect. The [fixed key-profile comparison](TONAL.md#fixed-key-profile-comparison)
uses one published Krumhansl–Kessler profile pair and Pearson correlation on saved
chroma. Its primary exact-match result falls from 66.865% to 32.016% on source 02
and 35.581% to 21.142% on source 16; all individual annotators also regress.
Reject this candidate. Inspect changed cell decisions and class contributions
before declaring a different observation/model; do not sweep profiles or smooth
the rejected output. The maintained tonal ranker remains unchanged.

The note cache inventory found no retained harmonic-fit intermediates matching
these windows. A native availability classifier now validates all 96 flute and
87 violin events, retaining provable branch exits and explicit unresolved
alternatives. It reads cached observations only. Changed frequency can establish
that phase-support checks were passed; unchanged frequency cannot distinguish
an early exit from exactly zero correction. No physical-cause, pitch-identity or
presence correction follows from branch attribution. The [native stage summary](PHRASE-EVALUATION.md#cached-availability-attribution--2026-09-21)
also passes: all unavailable triples remain unresolved, with no uniquely
attributable frequency/target-energy exit. The next note step is a predeclared
trace-only replay per existing development recording, retaining first exits and
reached intermediates. Exact original-output equality is required before any
interpretation; no model run, new source or prediction change is authorized by
this diagnostic. The envelope correction stays stopped.

Controls and data paths pass with zero leaks; the key study also rejects wrong
prediction identity and preserves existing output. Both sources' predictions
freeze before reference comparison. Final commands, hashes, resource measurements
and verdicts are under `build/qa-batch-11/`; no scientific aggregation is performed
in shell. No task closes, failure counter resets or credits change:
**62.65%, 38 open / 11 DONE**. The originating NS-5 style/corpus goal still depends
on accepted note/context evidence and its learning bridge. Final documentation
checks pass: native evidence, local links, task accounting, privacy and the six-file
scope are verified. The batch is ready for normal publication; its exact revision
is reported separately. No runtime process remains live.

## Previous checkpoint — frozen note/key diagnostics accepted — 2026-09-21

The final QA batch passes the corrected native note-cache and key-error audits,
plus the native note-cohort summary. These diagnostics change the next experiments,
not the accepted musical scores. [Note reassessment](PHRASE-EVALUATION.md#identity-evidence-reassessment--2026-09-21)
reconciles all 5,994 centers and stops the proposed envelope correction at its
declared evidence gate. Available lower-register measurements still oppose the
guard in 32 of 43 triples across the 11 flute error events; upper evidence is
missing in 25 of 43. Next identify exact availability failures under unchanged
observation rules, starting with the retained cache inventory. No new waveform or
model experiment, forced octave correction or threshold sweep follows.

The [key-error audit](TONAL.md#frozen-key-error-audit) shows source 16's net
264,600-frame exact-match loss within fully labelled constant contexts, alongside
the same net increase in relative-key errors. Reference ranks reach fourteenth.
Next predeclare one key-specific tonic/mode weighting hypothesis on frozen chroma
before investigating temporal smoothing. Preserve each annotator, gaps and the
no-source-regression gate; the existing core ranker remains unchanged.

QA repaired two diagnostic implementation defects: abnormal controls termination
leaked an argument temporary, and an inferred fixed-width string collection
truncated a coverage field name. The former is one blocking helper submission;
the latter is primary-owned. Corrective checks pass with zero leaks; retain
historical counters and distinguish scientific rejection from implementation
failure. Original successful note data was not recomputed after cleanup. Its
report retains the original producer identity, while the native summary binds
that report explicitly. A shell convenience aggregation was replaced as evidence
by Pascal output. Full commands, resource measurements, failure/repair identities
and verdicts remain in `build/qa-batch-10/report.txt` and the linked topic records.

Accounting stays **62.65%, 38 open / 11 DONE**, with no task moved or partial
credit. The current return path remains NS-5 corpus/style acceptance through
dependable recorded notes and context; raw inference execution already passes.
Final documentation QA passes: native report identities, local links, task graph,
credit arithmetic, privacy and staged scope are checked. The nine-document batch
is ready for normal publication on `hello-pythian`; its published revision is
reported separately. No runtime test process remains live.

## Primary review completed; dedicated cycle inactive — 2026-09-21

The user authorized the primary agent to perform the infrastructure review and
then removed the dedicated senior reviewer from the active cycle. There is no
two-DONE-task review trigger or reviewer prerequisite for future QA batches.
[Task flow](TASKFLOW.MD#infrastructure-review--dedicated-cycle-inactive) records
the current arrangement and retains the former rotation as historical guidance.

Primary review of published `d16c758` and its changes since `bc9bac82` found one
documentation defect: the workload plan counted one full-source hash per job,
where the maintained worker hashes before and after observation. The corrected
[workload record](CORPUS-SCALE.md) counts six hashes for the three long-source
jobs and four for the two pilot jobs, with final source verification inside the
total job budget. The existing [scale task](TODO/NS-5_scale_01.md) owns this cost;
no new task, raised budget or repeated benchmark is needed. Retained hour timings
already include both passes. The finding does not reopen native qualification.

No new implementation defect was found in the bounded supervision, tonal-evidence,
scale-dependency and delivery-boundary review. Six native implementation/fixture
hashes and the seven-file timed study/reference manifest still match accepted
evidence. Detailed scope, source lines, finding and limitations are retained in
`build/big-boss-05/REVIEW.md`. This is a primary review, not an independent-agent
verdict or new runtime QA. Accounting stays **62.65%, 38 open / 11 DONE**;
review activity creates no credit or failed QA submission.

After runner reload, the assigned QA role successfully resumes and completes
the two-item diagnostic batch recorded above. No temporary primary-agent QA
exception is needed. This supersedes the prior scheduling blocker below; the
dedicated senior review cycle remains inactive.

## Saved handoff — prior review scheduling blocker — 2026-09-21

The user explicitly requested another infrastructure review before the routine
two-closure threshold. The implementation helper saved its note-identity cache
audit and ended its turn with no live processes. Its tracked study change is
the pending-preparation paragraph in
[note identity](TODO/NS-3_notes_01.md); its ignored source, frozen policy and
QA commands are under `build/phrase-identity-reassessment/`. It compiled on
checked stable Win64 but has no execution or acceptance result.

While reviewer scheduling remains blocked, the primary agent has prepared the
next independent [key-evidence diagnostic](TODO/NS-3_context_01.md) under ignored
`build/local-key-reference/swd/error-audit/`. Its predeclared policy and native
implementation classify frozen ranking errors and reference ranks by original
frame intersections, annotator and context coverage. Fully labelled constant
contexts remain distinct from missing/discontinuous labels. Checked stable
Win64 compilation passes; controls and saved-data execution remain with QA.
The two diagnostics now form a ready batch; their source/policy hashes and exact
commands are in their QA packets. No new musical result or task acceptance is
inferred, and no additional recording is exposed.

The runner rejected both creating and resuming the authorized senior reviewer
with `agent thread limit reached`, including after interruption of the completed
helper. The available operations expose no session-removal action. No new review
has run, no reviewer verdict exists, and QA has not been restored. The prepared
review packet is `build/big-boss-05/HANDOFF.md`. Resume that review when a worker
session can be released, then restore QA with the saved queue and counters.
Review 04 remains the last completed checkpoint, followed by one accepted
closure. Accounting stays **62.65%, 38 open / 11 DONE**; no task or credit changes.

The same scheduling rejection is verified across three consecutive goal turns.
The retained helper is terminal, no review/test process is live, and both next
diagnostics are prepared for the authorized QA role. Further inference changes
depend on those results; selecting another experiment before execution would
bypass the declared evidence gate. Goal execution is blocked pending release
of a retained worker session, additional runner capacity, or explicit revised
staffing instructions. Preserve all local work and resume with review 05,
then the two-item QA batch; do not restart or rescore accepted observations.

Published revision `d16c7586e84dd3b528fb9b2ac4209bd46f24959b` now has successful
[exact-head native CI](https://github.com/mr-highball/pythian/actions/runs/35592253078).
That evidence covers the existing native workflow, not the pending review or
unexecuted cache audit. The review scheduling and workflow clarifications remain
local pending QA; no new publication is claimed.

## Previous checkpoint — timed key evaluation and corpus workload prerequisites — 2026-09-21

The fixed timed local-key diagnostic is implemented under ignored
`build/local-key-reference/swd/timed-key.lpr` and compiles on checked stable
Win64. The predeclared `TIMED-POLICY.md` binds two previously exposed compositions,
full-source baseline/peak feature lattices, identical four-second cells and
eight-second contexts, and separate annotator/coverage scoring. Neither the
source nor thresholds were tuned against these timed results. Final QA runs
controls, observes both WAVs before comparison, and passes identity, duration,
resource and heap checks. The scientific gate fails: unanimous-frame exact key
matching changes from 46.776% to 66.865% on source 02 and 47.481% to 35.581% on
source 16. The mean improves, but the predeclared no-source-regression condition
does not. The [tonal record](TONAL.md#timed-development-comparison) preserves all
rankings, annotators, gaps, unknown duration and the concrete D-minor/F-major
ambiguity. Next inspect tonic/mode and temporal evidence before declaring a new
hypothesis; no retuning, maintained key adoption or completion credit follows.

The independent [scale preparation](CORPUS-SCALE.md) identifies three development
recordings with 2.3222053373 unique original-clock hours and prospective raw-job,
storage, preparation and capacity budgets. Complete semantic workload commands
cannot yet be supplied: raw salience lacks the admitted-note-to-learner bridge.
The [scale task](TODO/NS-5_scale_01.md) now links its actual existing prerequisite,
[recorded phrase admission](TODO/NS-3_notes_03.md), which follows note identity and
presence development. No extra task, inferred independent song, benchmark or
credit is created. The graph gains one edge, without a cycle or changed task
count. Final QA accepts the preparation's metadata, exact duration/count
arithmetic, capacity statements and acyclic linkage, while all five full scale
criteria remain unfulfilled. Its preparation failure count stays zero.

Batch 09 evidence is in `build/qa-batch-09/report.txt` and the frozen timed/scale
handoffs. Timed observations complete once each in 7,360 / 10,078 ms including
serialization, with zero owned leaks and unchanged frozen identities. A failed
scientific hypothesis is not a code defect or failed implementation submission.
The graph now has 49 tasks and 95 edges. No task moves or credit changes follow.

Published inference repair `5eb5bfe335e904b01087ca7a9df9860ff41b15c9` passes
[exact-head native CI](https://github.com/mr-highball/pythian/actions/runs/35590706260),
covering Linux core/WFC integration and extracted consumers. The optional Win64
runtime has its separate focused evidence below. Accounting remains **62.65%,
38 open / 11 DONE**; review 04 is followed by one accepted closure.

## Accepted checkpoint — coherent native supervision — 2026-09-21

The [native execution task](TODO/DONE/NS-3_validation_02.md) is accepted again
after the review's progress race is repaired. Phase and full timestamp are one
aligned atomic word; the supervisor decodes one captured snapshot, including
terminal validation. No worker-held lock or snapshot retry loop is introduced.
Final checked stable Win64 QA passes the coordinated second-mapping publisher
regression and seven subprocess cases. A healthy six-second setup transition
survives; real stall/setup/total limits reject; cancellation completes in
266/265 ms including the 200-ms request delay; every failure preserves output.
The real-worker replay is byte-identical to its retained 48-kHz stereo artifact,
with 44,187 ms total, 19,968 ms setup and 103,153,664-byte peak private memory.
Both initialization failures and long-source setup cancellation pass. Terminal
logs report zero owned leaks. The final source identities match the handoff.

Evidence is retained in `build/native-inference/progress-repair-QA.md`,
`progress-repair-hashes.json` and `build/qa-batch-08/report.txt`, with the two
`progress-repair-*.log` files. Model arithmetic, waveform preparation, artifact
encoding, source identity and budgets are unchanged; earlier numerical/rate/
recorded/hour evidence remains valid without repetition. This restores all five
criteria and the original **+5 NS-3 / +1.25 overall points**, giving **62.65%,
38 open / 11 DONE**, 49 total tasks, 19 active outcomes, 7.15 accepted points
and 37.35 remaining. It is not new credit for a second implementation.

This is one accepted closure after review 04's ten-DONE checkpoint; another
accepted task is needed for the next routine review. The historical failed QA
submission count stays at one. The [whole-pipeline workload task](TODO/NS-5_scale_01.md)
had its native-execution prerequisite restored. Subsequent workload preparation
above identifies the separate admitted-note bridge that still blocks full scale
qualification. Timed-key work remains development evidence, without musical
admission, genre acceptance or independent key accuracy claimed.

## Historical review — native supervision reopening — 2026-09-21

The reopening and prepared-repair states below are superseded by the accepted
repair above; retain their evidence and accounting history.

The explicitly requested early infrastructure review inspected published revision
`bc9bac82fb30ea7bf5412cd6eb49587bbfed8517` and its interactions with the portable
core, WFC, source/time contracts, acquisition, packaging and recorded evidence.
It confirmed one P2 defect: the supervisor can combine a stale startup timestamp
with the worker's new observing phase and terminate a healthy worker as stalled.
The primary review agrees with the concrete source interleaving. The
[native qualification record](NATIVE-INFERENCE.md#qualification--2026-09-21)
and [reopened execution task](TODO/DONE/NS-3_validation_02.md) contain the trigger and
required coherent snapshot/transition regression. No duplicate task is needed:
the existing fourth criterion already requires correct bounded supervision.

Reopening withdraws **5 NS-3 points (37% to 32%)** and **1.25 overall
(62.65% to 61.4%)**. The catalog returns to **39 open / 10 DONE**, 49 total tasks,
20 active outcomes, 5.9 accepted points and 38.6 remaining. Numerical/resource
evidence, including the successful hour, is preserved; no budgets are relaxed.
Dependent workload acceptance is blocked again. Review does not increment the
task's historical one failed QA submission. No implementation changes were made
during review. The next step is the scoped supervision repair and focused final
QA, then return to the saved NS-5 workload and NS-3 local-key work.

The repair is now prepared: phase and full timestamp share one aligned atomic
word, and supervision decodes both from a single captured snapshot. Consumer
and fixture compile together on checked stable Win64. Focused QA runs under
`build/native-inference/progress-repair-QA.md`; no acceptance is restored until
its coherent transition, timeout/cancellation and real-worker replay gates pass.
Model arithmetic, waveform preparation, artifact encoding and budgets are
unchanged, so the retained successful hour does not require repetition.

Separately, the next local-key development comparison is declared before scoring
in `build/local-key-reference/swd/TIMED-POLICY.md`: two already exposed timed
references, identical source support and fixed baseline/peak representations,
separate annotator denominators and preserved gaps/disagreement. It is not yet
implemented or run and earns no credit. Other compositions remain untouched.

Review 04 is complete, with its detailed source report retained under
`build/big-boss-04/REVIEW.md`. No second actionable defect or separate missing
task was established; all six inspected maintained Pascal identities match the
accepted QA submission. The reviewed checkpoint is the ten tasks still accepted
in DONE after reopening. Count two subsequent accepted task closures from this
checkpoint before the next routine review. QA resumes with the saved evidence,
failure count and no live processes; final testing and publication remain its
responsibility.

## Historical acceptance — native observations and key-reference evidence — 2026-09-21

The acceptance below preceded the supervision finding and is superseded by the
reopening above. Its measurements and publication evidence remain historical.

[Practical native inference](TODO/DONE/NS-3_validation_02.md) now passes all five
criteria and moves to DONE. The optional Win64 consumer emits 360,000 raw
observations from one continuous hour in 2,420,266 ms, with 20,313-ms setup and
103,051,264 bytes peak worker private commitment. The complete 524,160,407-byte
artifact passes verification and publication. Final logs report no owned leaks.
The fixed numerical/rate/channel/recorded/failure cases and five-minute workload
remain accepted; focused startup requalification repaired the first hour failure
without changing budgets. Its historical failed-submission count stays at one.
Exact final evidence is in `build/qa-batch-08/report.txt` and
`submission2-hour-report.json`; the [native contract](NATIVE-INFERENCE.md#qualification--2026-09-21)
records the accepted scope and continuing accuracy/platform obligations.

Acceptance adds **+5 NS-3 points (32% to 37%)**, **+1.25 overall (61.4% to 62.65%)**.
The catalog has **38 open / 11 DONE**, 49 total tasks and 19 active outcomes;
accepted task credit is 7.15, with 37.35 overall points remaining. WAV-VALIDATION
closes, and the [many-hour workload task](TODO/NS-5_scale_01.md) is unblocked.
It must include complete-source verification and any preparation cost/lineage.
This is one completion after the infrastructure-review checkpoint at ten DONE;
the next routine review requires another accepted task. Final owned-document links,
task graph, credit arithmetic, unchanged implementation identities and staged-scope
checks pass. Published revision `bc9bac82fb30ea7bf5412cd6eb49587bbfed8517`
matches `origin/hello-pythian`. Its [native CI run](https://github.com/mr-highball/pythian/actions/runs/35588031109)
passes the Linux integration build and extracted core/WFC consumer packages.
That run does not exercise the separately qualified Win64 inference runtime.

The root-owned local-key work also has new bounded evidence, with no extra credit.
The two selected timed references pass native original-byte/clock/partition
preflight, retaining each annotator's labels, gaps and disagreement. The fixed
peak experiment passes twelve known-tone controls and silence, correcting five
default-bin dominant-class errors. Its two exposed WAV observations complete
before interpretation: declared A major improves from rank 2 to 1; D minor stays
at 1. All original six/seven crop boundaries and 24 candidates are preserved;
both runs meet their declared work/time limits and report no owned leaks.
[Tonal evidence](TONAL.md#recorded-key-reference-comparison) records source/policy
identities, measurements and limits. No source annotation becomes a prediction,
and no maintained key estimator, calibrated confidence or independent acceptance
is claimed. Next test this representation on the prepared timed development
references, while the independent workload task follows its newly accepted
execution prerequisite. The style-card task remains open for complete genre
references and grounded numerical criteria.

## Historical batch preparation — reference cards and bounded native inference — 2026-09-21

The preparation and intermediate pending/failure states below are superseded by
the accepted checkpoint above; retain them as evidence of the actual sequence.

The primary NS-5 chain remains [style reference specification](TODO/NS-5_evaluation_01.md).
Three [candidate cards](STYLE-CARDS.md#candidate-reference-cards) now bind exact
original WAV sections to declared work/catalogue associations, existing acoustic
measurements and the missing annotations for each required musical dimension.
Primary artist/label descriptions support candidate stoner-rock, lofi and
chillwave associations; actual recording/edition correspondence remains unresolved.
B-middle replaces the crossing B-early section for this candidate packet without
creating new material or changing development exposure. These are not accepted
genre cards, calibrated criteria or extra completion credit.

While those musical annotations remain missing, the primary agent also follows
`NS-5_vocabulary_01 -> NS-3_context_02 -> NS-3_context_01` to a bounded
[key-reference comparison](TONAL.md#recorded-key-reference-comparison).
The unchanged ranker will receive original WAV chroma and separately supplied
note-duration profiles to distinguish measurement from interpretation limitations.
The fixed policy precedes observations: whole excerpts plus eight-second local
crops, existing analysis defaults, explicit source-frame intersections and no
threshold sweep. Both WAV-only reports must precede reference comparison; whole-
excerpt key conventions cannot become local ground truth. Both private Pascal
WAV observations now pass QA. The second reference comparison exposed a root-owned
mode assumption: its annotation says D minor, not D major. The repair preserves
both observed reports and the original observer source, binds exact identities,
and compares the declared mode; comparison-only requalification now passes.
A major ranks second from WAV and first from supplied notes; D minor ranks first
from both. The fixed policy selects waveform representation for the next
investigation, while preserving local-key and confidence uncertainty. The failed
comparison remains recorded and does not increment the helper's failure counter.

The implementation helper's ninth assignment is
[practical native inference](TODO/DONE/NS-3_validation_02.md), an independent prerequisite
of many-hour resource work. The agreed [optional Win64 observation strategy](PROVENANCE.md#optional-native-observation-adapter)
retains Pascal graph assembly, stream preparation and supervision around the
pinned CPU runtime. It emits raw converted-model salience and AC RMS; the failed
note-admission policy remains rejected. The adapter, consumer and fixture are now
code-complete and compile cleanly with checked stable Win64 settings. Source
review found no new confirmed defect. QA now passes the contract/failure controls,
twelve scalar comparisons, the six rate/channel cases and both recorded
2,997-row numerical comparisons. The five-minute 48-kHz stereo case also passes:
30,000 observations in 259,797 ms, 20,687 ms setup and 101,515,264 bytes peak worker
private commitment. The continuous-hour job fails at approximately 30 seconds
with a generic time/progress budget error; the exact phase/cause is unproven.
This is the first blocking submission for the helper's task. All handles are
terminal and no retry occurred. The helper's startup repair now compiles: bounded
source and runtime initialization overlap and must join before measurement;
phase-specific diagnostics retain the original budgets. Focused QA now passes
diagnostics, exact prior-artifact replay, source/model failure preservation and
long-source startup cancellation, with zero owned leaks. The original hour
command is running once under QA ownership; its result remains pending. The
second blocking submission would transfer the existing
task and implementation to the primary. No completion credit or publication
follows from these partial passes.

The private plan under `build/native-inference-plan/` declares setup <=30 seconds,
complete-job time <=30 seconds plus audio duration, <=2 GiB worker private memory,
<=100 observations/second and bounded batches before any benchmark. Short rate/
channel controls, a five-minute resampling probe and one real continuous one-hour
WAV-C development scope separate boundary coverage from long-source execution.
These remain the frozen acceptance limits. Initial checks do not preaccept the
continuous-hour case or establish musical inference accuracy.

The primary agent owns candidate cards, dependency/provenance decisions, pinned
asset acquisition and optional build integration; the helper owns isolated new
adapter, consumer, fixture and topic files. The asset script acquired verified
existing caches into `build/inference-assets/`, preserving all notices and hashes;
acquisition session 13077 ended successfully with no new runtime execution.
The separate `tools/build-inference.ps1` compiles only the optional Win64 consumer
and fixture with checked optimized flags; its invocation awaits final QA.
Ordinary builds and CI do not acquire inference assets.
Final feature testing belongs to QA. The first combined batch has returned its
partial passes and one blocking failure; assignment nine's repair is now back
with QA, with one failed submission recorded.
Completion remains **61.4%**, with **39 open tasks and ten DONE**.

The user requested an immediate additional infrastructure review. The helper
returned at a safe boundary with no live processes, frozen source hashes and the
acceptance-mapped handoff under `build/native-inference/`. Review scope and saved
QA state are in `build/big-boss-03/REQUEST.md`. The completed source review is
retained in `build/big-boss-03/REVIEW.md`: no confirmed new defect or accepted
blend regression, no new TODO, reopening or credit change. Twenty handoff source
identities match. The review traced blend/reblend lineage, loader/acquisition,
source support geometry, staging ownership and supervised publication; it ran
no product or inference tests. Its checkpoint is now **ten DONE**, with zero
subsequent completions; the next routine review follows two more QA-accepted
tasks. The reviewer returned and QA resumed batch 08 on the frozen sources;
QA subsequently returned the first failure handoff and has now resumed its
focused second submission on the repaired startup boundary.

Historical pre-submission repair: while reviewer activation remained unavailable,
primary integration inspection
identified a concrete staging-file ownership defect within the current inference
task: construction checks an unused path, but a later sink start can truncate a
file created in the interim. A failed open also marks the sink started before it
owns a file, allowing cleanup to target another artifact. The implementation
helper resumed a narrow repair for exclusive creation and ownership-aware
cleanup, with focused preservation fixtures and compilation only. This work does
not substitute for the requested senior review or final QA. Assignment nine
still has zero failed QA submissions. The repair now compiles: atomic exclusive
creation acquires ownership, and abort deletes through the owned handle before
closing it. Three focused preservation cases are added but unexecuted. The
helper returned with refreshed source hashes and no live processes. Final runtime
QA remains pending. The additional root-owned handoff at
`build/native-inference-plan/ROOT-QA.md` covers pinned acquisition/build behavior,
candidate-card evidence and the fixed local-key diagnostic, with resource
benchmarks separated from other CPU and hashing work.

During the active QA batch, the primary agent screened a
[published local-key reference candidate](TONAL.md#local-key-reference-candidate)
for the missing timestamped change evaluation. Metadata identifies original WAV
and annotation material; no new audio was acquired or scored. Admission must
first bind exact recording/annotation identity, notices, clock alignment and
ambiguity policy, keeping composition versions grouped across evaluation splits.
The fixed two-source diagnostic and its policy remain unchanged. This is progress
within the existing NS-3 context task, with no additional task or credit. With
benchmarking stopped, the exact 517,380,038-byte archive was acquired under
ignored `build/local-key-reference/swd/` and passes its publisher checksum and
local SHA256 identity. Original README/notices and only two HU33 development
compositions' three local-key annotations were inspected. Annotator disagreement
and gaps are explicit, and all performances of those compositions remain in one
development exposure group. The bundled README version and SC06 notice differ
from the surrounding metadata; preserve the originals and select HU33 only.
No new audio scoring, source admission or percentage credit follows. Preparation
is terminal before the resumed native-inference resource measurements.

While the resource run continues, a separate private Pascal reference preflight
is prepared for the same local-key task. It retains each original annotation,
converts exact decimal seconds to original frames and partitions unanimous,
disagreeing, partially labelled and unlabelled coverage. The policy is frozen
before execution; compilation and final QA are queued after the resource run.
It performs no key prediction or calibration, and no reference-packet result
is claimed until that QA completes. Preparation changes no maintained algorithm.

Read-only analysis inspection also identified the default extractor's coarse
low-frequency bin mapping as a concrete representation limitation. A single
private spectral-peak experiment is prepared with frozen interpolation, pitch-
class weighting and stop/switch policy. Twelve known-tone controls precede the
two previously exposed WAVs; original baseline observations are reused. The
ranker and maintained analysis remain unchanged. Source/policy identities and
queued commands are in `build/local-key-reference/PEAK-QA.md`; compilation and
execution wait until the hour resource run and reference preflight finish.

## Accepted selective semantic blends and reference controls — 2026-09-21

The primary NS-5 chain returns to [style references](TODO/NS-5_evaluation_01.md)
after the repaired validation prerequisite and clean second infrastructure review.
The [reference screen](STYLE-CARDS.md#reference-screening-and-musical-controls--2026-09-21)
has acquired two original WAV/annotation pairs with verified publisher archive
checksums and exact file bindings. Final checked stable FPC 3.2.2 Win32/Win64 QA
accepts the native musical distribution controls. The two references retain
403/547 supplied notes, with identical derived counts/frame rows and distances
within 1e-12 across targets. Supplied beat grids, instructed/performed chords,
string-derived notes and unspecified confidence retain their different meanings.
The examples remain development material with no target genre assignment or
calibrated acceptance threshold. No recording inference or listening verdict ran.
Retained source descriptions also expose a declared song boundary inside B-early
(120..150 seconds, boundary at 125). A native nine-excerpt binding/overlap audit
passes with byte-identical target reports: eight single-chapter excerpts and
one crossing. This supplies a concrete
segmentation warning while retaining unverified acoustic boundaries, broad family
exposure and existing corpus-task ownership.

The implementation helper's eighth assignment,
[selective semantic blend/reblend](TODO/DONE/NS-4_styles_02.md), passes all five
criteria on its first submission with zero failed submissions. The design keeps
original joint observations bound to parent archives,
while independently normalized marginal contributions control generation. Exact
repeated material needs an explicit deduplication/addition policy; conflicting
partial overlaps and incompatible active contracts reject. Actual WFC learner
composition, sound selection, retained exposure and unchanged unrelated controls
pass, including live named-session tokens/states and sound-only paired edits.
Source/control regression and blend/further/diamond replay pass; all 28 target-local
artifact comparisons match. The current encoding is extended directly without
historical readers. No dependency source or portable-core behavior changed.

All ten runtime logs in the combined batch report zero unfreed blocks. Commands,
tested source hashes and criterion review remain under `build/qa-batch-07/`.
Paired native sound differences are numerically verified; listening remains
unassessed. Reference preparation earns no partial credit and leaves style cards
open for grounded genre references and calibrated criteria.

Styles02 is DONE with incoming links repaired. NS-4 **92% -> 96%**; overall
**60.8% -> 61.4%**, with **39 open tasks and ten DONE** across 20 active outcomes.
Baseline 55.5 + accepted 5.9 = 61.4, leaving 38.6 points. Outcome packages remain
larger than ten points: 22.6 + 16.0. This is one post-review completion event;
another accepted DONE event is required before the next infrastructure review.
Final checks confirm unchanged tested source hashes, 2468 valid local links and
the 49-task/94-edge acyclic graph with reconciled credits. This validated batch
was published to `origin/hello-pythian` as `666dee7`. Its
[native CI](https://github.com/mr-highball/pythian/actions/runs/35575456413) completed
successfully. Generated/private artifacts and dependencies remained excluded.

## Accepted semantic persistence, duration edits and admission repair — 2026-09-21

Final QA accepts three tasks on checked stable FPC 3.2.2 Win32/Win64:

- [Shared musical validation](TODO/DONE/NS-3_validation_01.md) now requires the exact
  prediction's bounded source/preparation/estimator ancestry. Eighteen controls
  reject missing bindings and distinguish reference-derived/shared annotation or
  secondary-estimator exposure from legitimate source access. Existing thirteen-
  output and phrase scoring retains its thresholds and denominators. Retained
  flute/violin predictions reproduce all 2997 centers and prior metrics; neither
  becomes independent evidence. The ignored exporter now binds the original
  inferred JSON bytes rather than target-specific numeric reserialization.
  Corrected estimator/prediction/ledger/case/report files are byte-identical across
  targets; actual CLI output differs from the producer only by terminal CRLF.
- [Semantic persistence](TODO/DONE/NS-4_styles_01.md) saves actual mapped/named WFC
  models, joint observed runs, contracts, exposure, frozen vocabulary and current
  optional sound profiles. Direct original clocks/ranges and hash-bound preparation
  bytes support exact rational contribution auditing across re-encoded excerpts.
  Fractional adjacency, explicit repetition, contradictory/missing lineage,
  source/derived replay, ownership/bounds/corruption and paired sound pass.
- [Duration/stream edits](TODO/DONE/NS-4_layers_04.md) stage actual duration/context
  continuations, recalculate cumulative timing and solve dependent named voices
  before atomic scheduling. Unequal grids, holds, unknown spans and finite
  endpoints pass. Exact native sample comparisons preserve committed notes and
  live effect history through rejected edits; changed future renders replay
  exactly. Whole-future musical regeneration is explicit; tempo-only edits retain
  musical states. Terminal processing failure requires a fresh bus/epoch.

All criteria and task prerequisites pass. The original fourteen runtime logs and
six exporter/CLI follow-up logs show zero leaks. Commands, tested source hashes,
all-criterion review and audio identities are retained under `build/qa-batch-06/`,
with focused evidence under `build/prediction-ancestry/`,
`build/semantic-provenance/` and `build/duration-stream/`. Actual listening remains
unassessed. These results accept infrastructure, not recorded provider accuracy or
useful genre styles. Maintained build orchestration includes both new adapters'
public consumer fixtures. No dependency source or historical format branch changed.

Move all three task files to DONE and repair incoming links. NS-3 **30% -> 32%**
restores its original +0.50 overall credit; NS-4 **84% -> 92%** adds +1.20.
Overall **59.1% -> 60.8%**, with **40 open tasks and nine DONE**. This is 1.7 points
above the reassessed checkpoint, of which 0.5 restores the prior failed admission
claim. Combine former outcome packages A and B into **23.2 remaining points**,
alongside C's **16.0**, retaining the user's larger-milestone direction without
inflating credit. Return to NS-5 style cards and calibrated references; weighted
semantic blend/reblend is independently ready after infrastructure review.

The batch is published at `7c9aaa6e53c7f2a4634e7a14d88d67c42e2ef0ae` on
`origin/hello-pythian`, with the remote commit verified. Its
[native CI](https://github.com/mr-highball/pythian/actions/runs/35571422985) passed.
Final integrated-document checks passed 2450 links in 122 documents and the
49-task/94-edge acyclic graph, confirming 5.3 accepted and 39.2 remaining points.
The publication preserves all tested maintained-source hashes; generated/private
artifacts and dependencies were excluded.

## Review and delegation checkpoint — 2026-09-21

The inaugural infrastructure review examined `a01bbfb` and pending semantic
persistence using seven previously completed tasks. It found missing prediction
ancestry admission and missing derivative contribution evidence. The first finding
reopened shared validation and withdrew 0.50 points; the second belonged to the
existing persistence criteria. Neither needed a duplicate task or new credit.
Its read-only findings and source hashes remain under `build/big-boss-01/`.

Persistence failed two delegated QA submissions: an insufficient-context fixture,
then incomplete derivative evidence. The primary agent took the existing code and
repair under the [ownership-transfer rule](TASKFLOW.MD#delegated-validation-and-publication).
The implementation helper's replacement assignment was duration/stream editing;
its first submission passed with **zero failed submissions**. Persistence retains
its historical two failures after primary-agent acceptance. Review findings do not
increment QA submission counters; no junior assignment ran in this batch.

This integration recorded **three post-review DONE completion events**, including
shared validation's repaired re-acceptance, triggering the second
[infrastructure review](TASKFLOW.MD#infrastructure-review--dedicated-cycle-inactive).
The review completed against published `7c9aaa6` and found no new confirmed defect
requiring a reopened task, new TODO or credit adjustment. Source inspection
confirmed the repaired prediction/derivative boundaries and traced staged duration
edits through committed-note validation and atomic native scheduler replacement.
All eight maintained QA source/build hashes matched. Core/companion ownership,
sound/context ancestry and package/build inclusion remained coherent. The detailed
source/line report is retained under `build/big-boss-02/REVIEW.md`.

The reviewer wrote no code and ran no runtime tests. Existing tasks already own
selective semantic blends, recorded workflow integration, many-hour scale and
listening; no duplicate backlog items were added. The review earned no completion
credit or additional failed-submission count. Its worker slot was released for
restoring QA with the saved terminal evidence and counters. **Nine DONE tasks at
`7c9aaa6` is the review checkpoint; one completion event has followed it
(selective semantic blend/reblend, now ten DONE).**
The next review triggers after at least two further QA-accepted DONE events.

## Retained inference experiments — 2026-09-21

Pitch and metrical studies remain evidence without provider completion. The pitch
experiment allowance is consumed: periodicity, spectral, companion-annotation and
phase comparisons show that a wrong octave can have real acoustic support while
blanket corrections reject genuine low notes. Preferred flute precision remains
91.57% against 98%; violin's 98.55% passes development only. Keep register and
presence unresolved rather than extend the rejected phase rule with another cutoff.

The fixed [metrical source-structure comparison](BEAT-TRACKING.md#metrical-source-structure)
compares repeated low/mid/high accents at half/same/double periods, retaining ties,
missing model evidence and source support. All nine ablations reproduce the prior
method. The candidate improves acceleration F1 .656250 -> .950000 and authored
regular 0 -> 1 while preserving deception/polyrhythm, but authored polyphonic and
changing-clock acceptance still fails: reject general adoption without tuning.
A canonical phase representation correction preserved the musical policy; the
independent recurrence audit's untyped clamp was corrected to Double without
changing predictions or the 1e-9 tolerance. All nine comparisons passed final QA,
with source/code/policy bindings and budget evidence. Eighteen predictions and
scores, all 36 successful zero-leak runtime logs, and earlier failures remain under
`build/beat-metrical-structure/`. No untouched evaluation or genre acceptance is
inferred. The [style specification](STYLE-CARDS.md) still needs grounded musical
references, verified genre assignments and calibrated numerical criteria.

## Accepted granular controls and rejected phase rule — 2026-09-21

Accepted [granular musical and sound controls](TODO/DONE/NS-4_layers_03.md)
after final QA on checked stable Win32/Win64. NS-4 moves **80% -> 84%** and
overall completion **59.0% -> 59.6%**, with **42 open tasks and seven DONE**.
Named preferences preserve training weights, hard constraints and unrelated
pending edits. Paired pitch/gain/pan/cutoff/timbre/envelope edits preserve unrelated
states and stems, with declared note-relative timing and lifetimes. Both voice
fixtures and six demos pass without leaks; all 24 target-specific artifacts match
baseline `c130452`. QA caught a timbre fixture selecting its existing default;
the corrected distinct-waveform edit passes, and the original failure is retained.
Evidence and tested identities are in `build/qa-batch-04/`.

The separate [predictive-phase study](PHRASE-EVALUATION.md#predictive-phase)
passed the frozen physical controls but produced no corrections on either
recording. Final audit confirms unchanged intervals, score centers and metrics:
flute precision 91.57%, violin 98.55%. The register task remains open without
credit. The experiment budget is consumed; reassess discriminating source
evidence for identity/presence before any further hypothesis or tuning. No new
held-out recordings were used. Genre labels, independent musical references and
calibrated style criteria remain missing from the NS-5 specification.

The user lifted the implementation helper's task cap and authorized one junior
helper assigned only by that helper, for isolated routine work. The current runner
rejected junior creation at its thread limit, so no junior assignment ran.
[Task flow](TASKFLOW.MD#delegated-validation-and-publication) records the authority
and ownership rules. Final validation and batch publication remain with QA.

The [prior published batch CI](https://github.com/mr-highball/pythian/actions/runs/35562878914)
passed at `c130452`; it does not validate this batch. These accepted controls and
records were subsequently published at `a01bbfb` on `hello-pythian`. The next
independent semantic tasks are changing-duration edits and saved semantic providers;
the primary musical-learning path still needs evidence that resolves its errors.

## Accepted style comparators and provider compatibility — 2026-09-21

Accepted [provider compatibility](TODO/DONE/NS-4_layers_02.md) after final
two-target checks and all five criteria passed. NS-4 moves from **76% to 80%**;
overall completion moves from **58.4% to 59.0%** (+0.60), with **43 open tasks
and six DONE**. The style specification remains open and earns no partial credit.

Returned to `NS-5_corpus_02 -> NS-5_evaluation_01` after publishing the prior
accepted batch at `8316138`. The [working style specification](STYLE-CARDS.md)
separates aligned provider accuracy from generated distributions and joint
relationships. It defines each provider's single-recording, unlearned and
within-song shuffle semantics, retaining the fixed seeds, 120-second listening
packet and 15-second paired edits. The cards remain unfrozen: genre assignments,
independent musical annotations and grounded numerical thresholds are missing.
Those gaps remain within the existing task, with no partial credit.

The [native CI run for that published batch](https://github.com/mr-highball/pythian/actions/runs/35561454286)
completed successfully at `8316138`; this does not validate the current edits.

Native `pythian.evaluation.style` compares exact-policy trait histograms with
equal recording-group mass, separate uncertainty counts and pooled/mean/minimum
coverage. A group with no known observations makes distance unavailable. The
maintained fixture exercises preserved versus broken joint relationships, a
99-to-1 duration imbalance and contract/count rejection. Final checked stable
FPC 3.2.2 Win32/Win64 fixtures pass with no unfreed blocks. The numeric helper
does not establish genre quality or reference authenticity.

The companion now admits explicit vocabulary, ordered role, pitch-basis, PPQ,
clock/scope and unknown contracts. Compatible replacement rebuilds actual WFC
dependencies and proves the result before publication, preserving unrelated
accepted states and named-session pending edits. The mapped wrapper reuses the
existing unequal uniform/partitioned grid rules. Source evidence retains exact
declared PPQ/origin conversions and original tick/frame coordinates. Unsupported
relative-key and acoustic-palette inputs reject explicitly. Both native fixtures
and six demo runs pass; all 24 target-matched audio/MIDI/JSON artifacts retain
their accepted baseline bytes, with no leaks. QA evidence/source identities are
in `build/qa-batch-03/`; replay commands/logs are in `build/provider-compatibility/`.

A native development study remeasured all nine original master WAV sections on
100-ms windows with hashes and geometry checked. Channel/polarity transforms
preserve RMS distributions; silence produces distance 0.88 for B early and 1 for
the other sections. Six masters touch PCM16 endpoints, a source-quality flag
distinct from the five previously flagged prepared derivatives. This does not
prove audible clipping or musical traits. Private observations and controlled
measurement inputs remain under `build/style-protocol/`; no new evaluation
recordings were opened. Final two-target studies agree on all counts, histograms
and distances; two RMS values differ only by 1e-17 and 6e-17, with no leaks.

Continue the NS-5 reference/specification task with actual grounded musical
annotations and quantitative criteria, then genre corpus coverage. Source labels
remain unverified; do not promote current detector output to truth. The separate
semantic-layer path then became ready for integrated controls. This validated
batch was published at `c130452` with its completion records.

## Accepted evaluation and named voices — 2026-09-21

Accepted [shared musical validation](TODO/DONE/NS-3_validation_01.md) and
[named voice passes](TODO/DONE/NS-4_layers_01.md) after final two-target checks
and criterion review. NS-3 moves from 30% to **32%** (+0.50 overall); NS-4 moves
from 70% to **76%** (+0.90 overall). Together they move overall completion from
57.0% to **58.4%**, with **44 open tasks and five DONE**. This is accepted scoring
and explicit-role mechanics; recorded provider accuracy and listening remain open.

The [file evaluator](EVALUATION-OPERATOR.md) binds thirteen musical outputs to
source/preparation/reference/policy/estimator bytes, explicit conventions, clocks,
uncertainty and complete declared ancestry. Bounded parent traversal rejects
inherited evaluation recordings, missing/cyclic parents, hidden families and
references derived from the evaluated estimator. Normalized units and annotation
input/output contracts are checked. Primary 30-ms beats remain distinct from
70-ms diagnostics. The current structured annotation/ledger contracts replace
their development drafts; no historical reader was retained.

Checked stable FPC 3.2.2 Win32/Win64 evaluation fixtures pass wrong/unknown/rest,
missing evidence, incompatible units/clocks/policies and exposure controls.
Original exposed flute/violin annotations and retained predictions reproduce
all 2997 centers and previous phrase metrics; full reports match across targets.
The four phrase gates are unchanged. Flute still fails precision; violin passes
development only. Unknown external training overlap remains ineligible. No new
inference or held-out input was used. Fixed next pitch/metrical hypotheses,
baselines, budgets and stop conditions are [declared](MUSICAL-EVALUATION.md#fixed-next-experiment-budgets).

The [named companion session](INDEPENDENT-VOICES.md#named-independent-voice-api)
owns cloned harmony/rhythm/voice models and typed choices, actual WFC constraints,
selective descendant regeneration and bounded collective proof passes. It retains
unrelated accepted states and pending edits, with recovery after expected failure.
The eight musical-layer bound remains. The demo uses the public API; an independent
caller exercises role edits, detached ownership, chords/holds/rests and failures.
Both target fixtures pass. Three target-matched demo scenarios reproduce all 24
WAV/preview/MIDI/JSON artifacts against frozen source `0ecfe34`, without unfreed
blocks. Commands, hashes and final criterion reviews are retained under
`build/qa-batch-02/` and `build/semantic-voices/`.

The earlier accepted [consumer contract](TODO/DONE/NS-6_delivery_01.md) and
[native checkpoint](TODO/DONE/NS-6_delivery_02.md) put NS-6 at **72%**. Clean stable
Win32/Win64 full builds, all four extracted packages and successful Linux CI bind
to source `0ecfe34`; [delivery evidence](NATIVE-CHECKPOINT.md) records notices,
closure, exact artifacts and the uninspected remote-download limitation. Final
accepted musical-workflow packages and an actual independent-use verdict remain.

Current dependency: `NS-5_corpus_02 -> NS-5_evaluation_01`. Shared validation and
corpus identity are now DONE. Return to the measurable style-card/comparator
specification, then genre corpus coverage. The independent semantic-layer path
can next address [provider compatibility](TODO/DONE/NS-4_layers_02.md). No genre style
is accepted; current note/context failures are unchanged by these infrastructure
and composition results.

Development checkpoints are authorized on `hello-pythian` for ongoing review.
Publish validated source with its task/milestone integration; generated outputs
and private recordings remain ignored under `build/`. This is not a release.
Athena remains pinned to merged main `909336d808f0c40b297426e23aa58426a75c6516`;
WFC remains `47fa3d8cb8f0f72bf53943eb5eb79758c8f22ce4`. No dependency source changed.

## Verified corpus identity checkpoint — 2026-09-20

The user authorized execution from the least-complete north star, NS-5 (25%),
following prerequisite tasks when blocked. Accepted
[NS-5_corpus_01](TODO/DONE/NS-5_corpus_01.md): two verified development recording
groups, 124.285714 unique seconds, 24 source/derivative bindings, five quarantined
full-scale preparations and eight negative controls. Actual native conversion,
journal learning, frozen-palette reuse, blend and saved replay pass checked stable
Win64, with 1943 observations, 138 WFC states and 134144 output frames. Family
exposure and outside-plan palette ancestors are audited through an external
hash-bound ledger; no automatic CLI enforcement, genre or listening verdict is
claimed. [Complete evidence](CORPUS-EVALUATION.md#verified-identity-pilot).

Task moved to DONE; +2 NS-5 points and +0.4 overall: **NS-5 27%, overall 55.9%**.
The next corpus task is blocked by style cards, themselves blocked by shared
validation: `NS-5_corpus_02 -> NS-5_evaluation_01 -> NS-3_validation_01`.
Current work follows [NS-3_validation_01](TODO/DONE/NS-3_validation_01.md); return to
NS-5 after resolving it. The unfinished semantic-provider edit remains separate.

## Task catalog checkpoint — 2026-09-20

Implementation is paused at the user's request. The review deliverable is the
[49-task catalog](TODO/README.md), with all tasks open and no new DONE credit.
[TASKFLOW.MD](TASKFLOW.MD) defines the requested template, prerequisite links,
gap creation followed by return to current scope, completion evidence, moves to
`TODO/DONE/`, link maintenance and percentage updates after each accepted task.

The catalog reconciles the prior 22 outcome owners to 3 synthesis, 17 WAV-learning,
7 semantic-composition, 17 corpus/style and 5 delivery tasks. NS-1 remains credited
at 100%, with independence/provenance preserved as cross-cutting invariants.
The remaining 44.5 overall points are allocated once across tasks; baseline stays
55.5 because writing a backlog does not establish completed capability. The old
M1–M7 allocation is replaced by three outcome packages worth 14.5, 12.5 and 17.5
points, with hard ordering owned by the individual task files.

Scope review includes verified recording identities/splits, all three genre
corpora and independent verdicts, inference fidelity/cost, role ownership,
timing/vocabulary compatibility, independent musical/sound edits, saved joint
providers, ancestry-aware blend/reblend, changing-duration/committed-stream edits,
balanced vocabulary growth, many-hour recovery, structure and independent delivery.
Existing accepted mechanisms are starting evidence, not tasks recreated for credit.
Topic links retain the prior outcome anchors through the milestone mapping.

Documentation validation passes: 49 templates, 94 valid prerequisite links,
no dependency cycles, and every task reaches the final completion audit. Per-goal
credits reconcile to 44.5 remaining overall points. The local-link audit checks
2272 links across 114 documents with zero errors. Audit tools and logs remain
ignored under `build/milestone-reassessment/`; no implementation tests were
needed for this documentation-only change.

The interrupted extension in `pythian.wfc.providers` adds draft harmony/rhythm/
voice choice decoding but has not been validated or integrated into a reusable
voice session. It remains outside the last verified package and is explicitly
owned by [NS-4_layers_01](TODO/DONE/NS-4_layers_01.md). No product source, vendor, branch
or index changes were made while authoring this task catalog. Stop here for the
user's review; do not automatically resume implementation or count any task DONE.

## Previous checkpoint — provider descriptions — 2026-09-20

The [shared provider descriptions](GRID-STYLE.md#provider-descriptions) now expose
the existing saved grid and duration passes as discoverable musical controls.
`CopyProvider` owns typed vocabulary choices, immediate projection dependencies,
saved preferences and scope. Uniform PPQ cells, held context and cumulative
generated spans remain distinct. Unknown key/performance, silence and missing
intensity are explicit. The existing `pythian.style providers` command inspects
the same public API without solving or writing style/audio artifacts.

An independent caller discovers a complete alternate joint choice, applies a
preference and hard lock through the actual named WFC session, and captures the
expected pitch/onset/intensity while retaining every independent key/tempo state.
Checked stable Win32/Win64 grid and held-performance consumers pass, including
ownership, failure preservation, unknown/silence and mixed-vocabulary controls.
The coupled CLI report matches across targets; timed versus held inspection and
invalid mode/count rejection pass. Existing WFC/RTL warnings remain, with no
owned-source warnings or reported leaks in the accepted checks.

The preceding and current Win64 voice executables produce identical WAV, MIDI,
preview and JSON bytes from the same preferred second-blend style. Actual WFC
PCM verification passes: 64 cells, 705600 stereo frames and 120 notes. This is
generation regression evidence, not a new listener verdict.

Fresh [source packages](PACKAGING.md#current-api-delivery) contain 84 core units
and 26 companion adapters. All extracted inventory/closure/example checks pass;
a separate copy of the maintained consumer uses only extracted library units and
passes the new grid/performance controls against separately supplied saved styles.
Evidence is ignored under `build/provider-descriptions/`. An initial performance
invocation selected an obsolete development style, which correctly rejected before
generation; the accepted run uses the fixture's specified current source.

WFC-LAYERS now owns extending these concrete descriptors/controls to harmony,
voice roles and sound, plus compatibility, persistence and changing-duration /
committed-stream policies. There is no new saved format, solver or inferred role.
Milestones remain **55.5 weighted points / 22 unfinished outcomes**. Recorded
musical admission remains the main bottleneck; genre styles are unaccepted and
listening feedback is pending. Branch/index/vendor state is unchanged.

## Previous checkpoint — rate-view strength — 2026-09-20

The [rate-view strength separation](PHRASE-EVALUATION.md#rate-view-strength)
isolates an important tradeoff in the preceding comparison. Keeping pooled pitch
ranking while restoring the original frame maximum preserves every previously
correct flute center and adds 35 correct centers overall. Coverage rises to
**84.1469%**, but precision is only **92.2629%**, still below 98%. Violin reaches
88.0848% coverage / 98.3043% precision, with two previously correct centers lost.

The independent audit reconstructs source-bound original/pooled/restored maxima
and verifies unchanged pooled activity measurements at every frame. The local
unknown-state cost equals the original at all 2997 frames of each recording;
global note decisions still depend on changed identity evidence. Paired scoring
shows the earlier 94.38% flute precision depended partly on suppressed strength
and lost coverage. Strength restoration retains 93 flute octave errors, so it
does not provide reliable identity/presence admission.

Ratio/tie/neutral/zero/rejection controls and a controlled observation-sequence
decoder replay pass. Both recorded predictions precede unchanged native scoring;
independent paired audits against both comparators pass. Original/original inputs
replay the preferred baseline exactly apart from declared metadata/time fields.
Actual transformed-model low/short/quiet/gap/mixture controls and independent
evaluation remain prerequisites. No new model run or held-out material is used.
Final checked Win64 builds have no warnings or reported Pascal leaks; evidence is
ignored under `build/phrase-rate-strength/` and all processes are terminal.

Keep the preferred baseline and separate identity/strength as a future observation
contract. Next work needs evidence that distinguishes the remaining octave/presence
errors while preserving recovered correct coverage, not another global strength
or weight adjustment. No maintained source, package, dependency or format changes.
Milestones remain **55.5 weighted points / 22 unfinished outcomes**; listening
feedback is pending.

## Previous checkpoint — playback-rate observations — 2026-09-20

The [playback-rate observation comparison](PHRASE-EVALUATION.md#playback-rate-observations)
tests an additional source of register evidence without changing decoder rules.
Half/double-speed views and mapped arithmetic averaging improve raw rankings,
but all three views still agree on sixty wrong flute octaves and multiple false
rests. Agreement is not calibrated pitch/presence confidence.

The fixed pooled condition improves flute precision **91.5727% → 94.3764%**, with
octave errors **105 → 71** and false-rest admissions **45 → 23**. Coverage drops
82.4553% → 81.9236%, and the 98% precision gate still fails. Violin coverage and
onset F1 regress while its four gates still pass. Paired accounting shows only
nine wrong flute centers become correct, while 28 become unknown and fifty
correct centers are lost to unknown. Keep the preferred baseline; the new views
are candidate evidence, not an admitted replacement.

Eight transformed-tone controls, exact source-coordinate checks, all four raw
recorded measurements, complete transformed-cache replay, independent reference
classification, unchanged native note scoring, paired accounting and both original
baseline replays pass. Actual short/quiet/gap/mixture controls remain required
before adopting the pooled condition; no held-out material is consumed. Final
checked Win64 runs have no compiler warnings or reported Pascal leaks. Initial
compile/share/path errors are retained under `build/phrase-rate-observations/`;
all processes are terminal.

Next register/boundary work must preserve useful view disagreements without
equating agreement with correctness or exchanging correct notes for unknowns.
Keep event presence and octave identity distinct, preserve the passing violin
and known articulation controls, then freeze before independent evaluation.
No maintained code, package, format or dependency changes. Milestones remain
**55.5 weighted points / 22 unfinished outcomes**; listening feedback is pending.

## Previous checkpoint — operator partition selection — 2026-09-20

The maintained `journals` operator now supports explicit
[training/development selection](CORPUS-EVALUATION.md#operator-partition-selection).
Every pair declares family, partition, identity status and previous exposure;
the complete supplied plan and source/cache bindings validate before learning.
Only selected observations reach palette/WFC fitting and generation. Evaluation
learning rejects, including known evaluation-source leakage through a saved
palette starter. The existing report records the complete invocation audit;
no new manifest format is introduced.

On checked stable Win32 and Win64, interleaved development/evaluation inputs do
not change the selected weighted training model or audio. Same-target reports
match explicit training-only construction after removing the new audit; existing
profile reload and compatible frozen-palette reuse pass. Cross-target model/audio
bytes agree, but six candidate-distance diagnostics differ in their last floating
digits, so full cross-target JSON equality is not claimed. Rejection controls
cover metadata, identity/exposure, empty selection, unselected binding errors and
palette leakage before publication. Original shell-harness failures are retained;
its flattened argument arrays were corrected before accepting negative evidence.

A-early and B-early also run as previously used, unverified development families:
60 seconds, 938 observations and 60 WFC states. Native comparison binds their
operator declarations, exact hashes and geometry to the prior inventory. The
generated 134144-frame stereo WAV at 16000 Hz and model match the explicit baseline.
This establishes the operator path, not verified independent recordings, style
quality or derivative-overlap auditing. Assets and logs remain under ignored
`build/journal-partition-operator/`. Final successful checked runs report no
unfreed blocks or new owned-source warnings.

[Refreshed packages](PACKAGING.md#current-api-delivery) pass complete inventories,
unit closure and delivered consumers on stable Win32 core / Win64 WFC. The package
workflow now retains selection/report parity and exposure/starter rejection checks
alongside its existing journal blend/reblend/fit/context/replay path. All processes
are terminal. Source, package and checkpoint hashes bind this focused refresh.

CORPUS-SETUP now retains identity, representative coverage and parent-range/family
auditing as its remaining work. Milestones remain **55.5 weighted points /
22 unfinished outcomes**. The central musical blockers remain trustworthy recorded
notes/base context and semantic providers; listening feedback is still pending.
Next musical work should seek discriminating presence/register/event evidence on
the existing recorded development failures before another threshold sweep or
model port, preserving unused phrase evaluation material until inference freezes.

## Previous checkpoint — library partition selection — 2026-09-20

The maintained journal library now exposes opt-in
[`SelectJournalPartition`](CORPUS-EVALUATION.md#library-partition-selection).
It checks the complete in-memory plan before passing selected descriptors into
the existing palette and actual WFC learners. Conflicting family assignments,
exposed/unverified evaluation material, unknown training groups, overlapping
source observations and invalid ranges reject. Returned descriptors are detached;
validation does not read or rewind borrowed journals and failures preserve an
existing caller result. The whole plan shares the existing analysis/mass bounds.

The checked stable Win32/Win64 journal fixture proves exact palette/model parity
with explicit training-only construction, no reads from other partitions and
selection/rejection ownership. Initial cursor assertions confused committed
progress with read position; direct read instrumentation replaced them. A separate
failure exposed managed-result aliasing, fixed by publishing only after successful
validation. Original failure logs remain under `build/journal-partitions/`; final
fixture runs report no unfreed blocks or new owned-source warnings.

[Refreshed source packages](PACKAGING.md#current-api-delivery) pass complete
inventories, owned-unit closure and delivered consumers on stable Win32 core /
Win64 WFC. The maintained journal fixture also passes as an external consumer
against only the extracted WFC package. This is scoped API delivery, not a new
clean-checkout/CI or independent downstream-use verdict. All processes are terminal.

Real recording identity, style coverage and parent-range/derivative auditing are
still caller work. The command-line operator does not yet consume the inventory
plan, and no untouched style evaluation corpus is established. No file format,
dependency or synthesis behavior changes. This closes the library-selection
subtask, not CORPUS-SETUP: milestones remain **55.5 weighted points / 22 unfinished
outcomes**, and listening feedback is pending.

## Previous checkpoint — corpus inventory and protocol — 2026-09-20

The [corpus inventory and evaluation protocol](CORPUS-EVALUATION.md) now provides
a concrete starting point for many-recording style acceptance. A native inventory
rechecks all eighteen master/prepared hashes for the nine pilot sections, their
decoded geometry/peaks, and the full native-prepared WAV-C derivative. The short
sections cover 270 seconds; the full C extent plus the disjoint A/B sections
cover **8415.6535 declared source seconds**, without counting C excerpts twice.
All are development material. No independent song identities, style assignments
or untouched evaluation sources are established. Five short sections still reach
PCM16 full scale; their original preparation caveat remains.

The private plan records source families, exposure, hashes, geometry and section
coordinates. A hypothetical independent split passes, while exposed/unverified
evaluation, cross-split family use, duplicate bytes and overlapping parent ranges
reject. Exact inventory replay passes on checked stable Win64 with no owned
warnings or unfreed blocks. The full derivative is rehashed/reopened; its prior
sample-level measurements are reused, not rerun. Evidence remains ignored under
`build/corpus-partition-study/`, and all processes are terminal.

The protocol declares initial per-style coverage floors, fixed seeds/durations,
listening positions/rubric, single-recording/unlearned/shuffled comparisons,
granular pass edits and saved blend/reblend review. These are pre-evaluation
requirements, not completed comparisons. Actual identities/trait cards, populated
independent splits, provider-specific measures/baselines and maintained plan
enforcement remain linked to the corpus/integration backlog. No new production
format or dependency is added. Milestones remain **55.5 weighted points /
22 unfinished outcomes**, with all three styles unaccepted and synthesis listening
feedback still pending.

## Previous checkpoint — joint model/candidate comparison — 2026-09-20

The [joint model/candidate comparison](BEAT-TRACKING.md#model-candidate-comparison)
now recovers the difficult polyrhythm at **.986301 F1 without supplied rate/band
hints**, using the maintained selection/reconstruction APIs and all four cached
source candidate pools. Deception recovers to 1.0 and arpeggio reaches 1.0.
However, doubling/acceleration fall to .772727/.656250 and all three authored
controls remain unacceptable. Missing model evidence stays unknown rather than
being silently filled. The general selection policy is not adopted.

The decisive new admission constraint is that common errors can have perfect
agreement: two doubling windows choose 75.25 BPM with 1.0 model agreement but
only .636364 reference F1. A higher agreement threshold cannot resolve that.
The next work must distinguish credible metrical alternatives and missing pulses
under changing patterns, preserving the automatic 03/04 gains and existing native
controls. Model confidence/admission remains uncalibrated.

All nine predictions precede scoring. The independent matcher audits all 4572
candidate comparisons and source/origin/interval bindings; controls and complete
04 report replay pass on checked stable Win64. Final runs have no owned warnings
or reported leaks, and all processes are terminal. Evidence, declared policy and
source/checkpoint hashes are under `build/beat-model-candidates/`. No maintained
code/package, format or dependency changes and no unused evaluation material
is consumed. Milestones remain **55.5 weighted points / 22 unfinished outcomes**;
synthesis listening feedback is pending.

## Previous checkpoint — learned beat-model reference — 2026-09-20

The [learned beat-model reference](BEAT-TRACKING.md#learned-model-reference)
ran through an owned Pascal caller and a pinned native ONNX CPU runtime in this
historical checkpoint; the foreign runtime is retired under the Pascal-only
requirement.
On the existing polyrhythm, automatic beat F1 improves from **.373626 to .918919**
without reference-supplied rate or band; full-output F1 is .906667. However,
deception falls to .705882, doubling to .790698 and acceleration to .622951;
all three authored controls score zero. The model is rejected as a standalone
replacement. Its observations offer evidence for joint metrical interpretation,
not an admitted clock or calibrated confidence.

All nine predictions precede reference scoring. Native one-to-one scoring,
independent match-count audits, source/report bindings and complete endpoint
accounting pass. Initial 02 inference exposed a prediction at the exclusive source
end; the reporting amendment retains/flags it without changing earlier logits
or silently dropping extras. Silence and peak/chunk controls pass, scoped native
mel comparisons agree within .001, and the complete polyrhythm report replays
exactly. Final checked stable Win64 runs have no owned warnings or unfreed Pascal
blocks; original compile and endpoint failures remain in the evidence. Runtime
allocation accounting and network export fidelity are not established by these
checks. All processes are terminal under `build/beat-model-reference/`.

Complete model/export/runtime notices and pinned identities are in
[provenance](PROVENANCE.md#beat-model-reference). No maintained code, package,
format or dependency changes, and no new held-out material is used. The next
comparison must reconcile model observations with source-supported timing
alternatives, preserve the passing native controls and represent conflicts or
missing evidence explicitly. Model fidelity/calibration and independent musical
acceptance remain prerequisites. This development result leaves milestones at
**55.5 weighted points / 22 unfinished outcomes**; synthesis feedback is pending.

## Previous checkpoint — conditional phase-path adoption — 2026-09-20

The [conditional phase-path comparison](BEAT-TRACKING.md#conditional-phase-path)
isolates and substantially recovers the preceding known-rate phase failure.
Near-96-BPM candidates contain a locally supported phase for all 37 reference
beats; the old local choice loses twelve, and joining loses one further beat.
Using existing path costs across the retained eligible pool reaches **.986301 F1**
(36 matches / zero extras / one miss), versus .864865 for local score selection
and .648649 for the old nearest-rate rule. Only 21/37 output positions retain
context-supported observations; full-output accuracy includes raw fallback.

`SelectBeatTrackPath` now exposes that reusable selection stage in the maintained
core, independently of measurement/refitting. Caller-filtered candidates, forced
breaks, explicit unknown windows and detached results feed the existing clock
representation. Source/score meaning and the musical base context remain caller
decisions. The known rate and band in this development comparison do not establish
automatic metrical admission. The existing combined-onset tool with a 95..97-BPM
range still scores only .410959 after alignment, demonstrating why retaining
phase evidence matters as well as the rate constraint.

Checked stable Win32/Win64 and trunk Win32 selection/tracking fixtures pass,
including an independently enumerated optimum, competing phases, breaks, replay,
bounds and ownership. The public query matches every conditional study field.
All nine earlier clock/alignment probes preserve their default results, and the
existing constrained-tool report/audio replay exactly. Its diagnostic cue WAV
passes identity/geometry/no-clipping checks (peak .814910889); listening remains
unassessed. Initial generated-check source errors and a Win32 fixture's extended-
precision literal comparison were corrected; final checks have no owned warnings
or unfreed blocks. No inference thresholds were changed to pass them.

[Refreshed source packages](PACKAGING.md#current-api-delivery) retain 84 core units
and 25 WFC adapters. Complete inventories, examples/journal workflows, an extracted
core path fixture and a byte-exact extracted conditional-path consumer pass.
Evidence is under `build/beat-phase-context/`; all processes are terminal. No
new full source-clone, Linux/remote CI, held-out evaluation or native format is
claimed. Automatic rate/pattern/phase inference and useful observed coverage
remain in the backlog; the conditional mechanism is completed. Milestones remain
**55.5 weighted points / 22 unfinished outcomes**, with synthesis listening
feedback still pending.

## Previous checkpoint — separate band pulse paths — 2026-09-20

The [separate band-pulse comparison](BEAT-TRACKING.md#band-pulse-comparison)
rejects raw per-band flux peaks as a replacement for localized onset admission.
Native controls recover simultaneous 96/144 pulses and swapped band roles, but
the nine existing development WAVs show calibration/polyphonic regressions and
no resolution of polyrhythmic beat identity. No reference-selected band is
promoted. Full-output scores include raw fallback; the reports separately retain
observed-only coverage/precision and every unknown decision.

The polyrhythm's high band retains a near-96-BPM alternative in all 24 windows
without choosing it. A declared diagnostic given that known rate reaches only
.648649 F1 (24 matches / 13 extras / 13 misses); phase remains unresolved even
after the rate choice is supplied. The next pulse work must jointly account for
competing patterns, metrical interpretation and phase, retaining those candidates
and the demonstrated stable/changing-rate failures as constraints.

The original 64-million per-stream workload rejects the dense 04 peaks. A separate
bounded study copy changes only the unit name/work constant; it preserves the
first three reports' musical fields exactly. All nine final inference runs precede
reference scoring. Native source-difference/binding/accounting checks, independent
matching and byte-exact complete 04 replay pass on checked stable Win64. Final
processes are terminal without owned warnings or reported leaks. Original work-
limit and evaluation-setup failures are retained under `build/beat-band-pulses/`;
final reports are in `expanded/`. Maintained limits, APIs, defaults, packages and
formats remain unchanged. No new held-out recording or listening verdict is used.

The backlog now links these concrete pulse and workload requirements. The goal
remains active at **55.5 weighted points / 22 unfinished outcomes**; the rejected
comparison earns no completion credit. The synthesis preview still awaits
listener feedback, while musical admission and corpus preparation remain runnable.

## Previous checkpoint — optional alignment adoption — 2026-09-20

The [optional alignment API](BEAT-TRACKING.md#alignment-api) is now maintained
in the independent core. Clock reconstruction opts in through
`bcaNeighbourSupported`; default independent behavior is unchanged. Results
retain original/selected observations, witness envelopes and explicit unknown
or unavailable context. Candidate and witness bounds preserve missing runs,
restarts and rejected phase intervals. Both native beat/context operators expose
`--alignment-context`, and caller-reviewed context admission binds the complete
decision report into the current saved WFC profile contract. Raw fallback is
explicitly a caller-reviewed clock, not observed-beat admission.

Checked stable Win32/Win64 and trunk Win32 clock fixtures pass, including
competing onsets, expressive ambiguity, drift, endpoint unknowns, barriers,
candidate limits, quiet evidence, detached results and failed-result preservation.
Existing track/context fixtures pass on stable Win64. Adoption reproduces all
nine study probes, both frozen paths on the six development inputs, and the
rejected localized diagnostic. This verifies implementation parity only; it is
not another independent evaluation. Default beat report/WAV and authored context
report/profile/WAV match their earlier checkpoints byte-for-byte. Optional
reports preserve every study decision; the cue WAV's hash/geometry and peak
.517486572 pass. Actual saved WFC replay passes on authored and recorded clocks,
with 23/37 pulse tones in 555660/701108 frames respectively.

The maintained build includes optional beat inspection and saved context replay.
The [refreshed packages](PACKAGING.md#current-api-delivery) contain 84 core units
and 25 WFC adapters; complete extracted inventories, examples, the core alignment
fixture and an external optional-context WFC consumer pass. The latter reproduces
workspace report/profile/audio exactly. No new full source-clone, Linux/remote CI
or independent-use result is claimed. Evidence is under
`build/beat-alignment-adoption/`. The active backlog removes
public alignment adoption and retains metrical selection, genuine timing versus
distractor ambiguity, evolving clocks, endpoint support and useful observed
coverage. No format fork, default promotion or accepted genre style is added.
Milestones remain **55.5 weighted points / 22 unfinished outcomes**. Listening
feedback on the supplied 30-second synthesis preview is still pending.

## Previous checkpoint — neighbour-supported alignment study — 2026-09-20

The [neighbour-supported alignment study](BEAT-TRACKING.md#alignment-context)
preserves raw clocks and scores only onset candidates whose offsets have local
support. It uses two adjacent beats on either side, with frozen original choices
as witnesses. Unsupported alignment retains the raw frame and explicitly records
unknown; inadequate context retains the original choice with an unavailable flag.
An isolated expressive departure and a distractor remain indistinguishable.

The six development paths do not regress. The arpeggio improves from .963855 to
.987952 F1, and the rejected localized doubling diagnostic recovers from .920000
to .960000. The latter still misses the real 6.796667-second beat, so its switch
model remains rejected. Abstention is substantial: joint-selected arpeggio,
doubling and acceleration retain only 28/42, 17/27 and 22/38 context-supported
onsets. Full-output accuracy includes raw fallback and is not observed coverage.

The unchanged rule was then checked on previously unused ARTBeaT IDs 01, 03 and
04. Each passes the declared conditional nonregression check: F1 .974359, 1 and
.373626 respectively, before and after. ID 01 is a calibration sanity check;
its first three annotation timestamps were inspected during format setup after
the rule froze but before the written protocol. IDs 03/04 audio and annotations
were unused until this evaluation. The dataset family is shared, not an
independent natural-music corpus. Used IDs are now **01, 02, 03, 04, 05, 19**;
the other **19** remain unused. Do not reuse these three as fresh held-out proof.

The deception case declines 20/44 snaps despite perfect full-clock accuracy;
the polyrhythm case still selects the wrong beat level, with observed-only
precision .40. Thus conditional refinement has evidence, automatic musical
admission does not. Checked stable Win64 controls, actual maintained-clock parity,
source/candidate binding, independent matching and complete report replay pass.
Evidence is under `build/beat-alignment-context/`. No maintained source, package,
format or default changes. Public adoption should preserve explicit mode choice,
unknown decisions and current replay, while automatic work must resolve musical
beat level and distinguish genuine timing departures from distractors. Milestones
retain 55.5 weighted points / 22 unfinished outcomes; listening is unassessed.

## Previous checkpoint — conditional switch localization — 2026-09-20

The [conditional switch-localization study](BEAT-TRACKING.md#switch-localization)
tests the early doubling error with two phase-continuous clocks and local
three-band cyclic templates. It recovers an exact authored switch and favors the
constant null on an unchanged control, but **fails the recorded upgrade gate**.
The selected join is 7.201112 seconds; raw F1 rises from .943396 to .960000,
while aligned F1 falls to .920000. It removes the two early extras but misses the
6.796667-second beat. The current alignment then moves a valid final raw beat
from 11.86 ms reference error to 38.71 ms, creating an extra miss/extra pair.

Band diagnostics preserve every original inference field and expose conflicting
preferred joins: low 12.001112, mid 7.201112, high 6.401112 seconds. The aggregate
cost improvement over both constant nulls does not establish correct timing.
Do not promote this fixed endpoint-template model or retune band weights/window
lengths on this recording. Next inference must handle evolving band patterns and
phase uncertainty; alignment also needs an evidence rule that protects valid
clock beats instead of always following the strongest nearby onset.

The other five development clocks are retained by the declared single-abrupt-
change applicability rule, so their unchanged results are not new localization
evidence. Checked stable Win64 controls, source binding, feature accounting,
phase-continuous joins, complete fit/clock replay and independent matching pass.
The detailed report replays byte-exactly. Raw/aligned diagnostic cue WAVs reopen
with bound hashes, source geometry and no clipping; listening is unassessed.
Evidence is under `build/beat-switch-localization/`, with no new maintained code,
package, format or independent-recording acceptance. Milestones retain 55.5
weighted points / 22 unfinished outcomes and now name these concrete remaining
inference requirements. The full goal remains active.

## Previous checkpoint — band relationship competition — 2026-09-20

The [band-relationship competition study](BEAT-TRACKING.md#relationship-competition)
now declines the known false rate bonus for changing band relationships while
retaining true doubling. It compares identity with three coherent reversals of
centered band activity, preserving pair identity and signed evidence. A winning
reversal excludes rate-only support; it does not prove unchanged tempo. The same
observation remains ambiguous when rate and relationships actually change together.

The six development WAVs retain every selected candidate and every reconstructed
raw/aligned beat: doubling F1 .943396, acceleration .948718, stable arpeggio .963855,
and all three authored cases 1. Both search bounds agree. A single opposing pair
does not impose a veto. Initial gating incorrectly removed the unity comparison
and inflated two scores; the retained correction separates measured availability
from rate exclusion. Corrected scores match the prior selected paths, and a
focused control proves exclusion cannot increase the rate bonus. Full report
replay, native controls, maintained-clock reconstruction and independent matching
pass on checked stable Win64 without compiler warnings or unfreed blocks.

Evidence and the initial failure are in `build/beat-relationship-competition/`.
This resolves one declared counterexample, not automatic arrangement or metrical
admission. No maintained inference code, package or format changes. Next pulse
work must locate changes within the intervals actually covered by descriptors,
resolve early-switch errors and broader arrangement alternatives, then freeze
for independent evaluation before adopting the selector. The milestone backlog
reflects that narrower remaining question; 55.5 weighted points and 22 unfinished
outcomes remain. No new held-out recording or listening verdict is used.

## Previous checkpoint — reconstructed-clock context — 2026-09-20

Explicit [reconstructed-clock admission](WAVE-CONTEXT-ADMISSION.md#reconstructed-clock-ranges)
now reaches the existing saved context and actual WFC key/tempo passes.
`AdmitBeatClockRange` reconstructs from caller-bound windows, observations and
options, then rejects ranges crossing gaps, restarts or unavailable/ambiguous
phase. It preserves source offsets, cumulative timing and caller-supplied key
or unknown. The context operator adds optional `--clock linear|step` to inspect
and admit, binding reconstruction policy and exact source/report hashes into the
current profile. No new format or automatic beat/key admission is introduced.

Checked fixtures cover accepted changing clocks, unknown key, independent timing
expectations and rejected ranges; clock and existing track fixtures pass stable
Win32/Win64 and trunk Win32. Authored linear/step and recorded linear admission
save/reload/generate through WFC: 23 intervals / 555660 frames for the authored
case and 37 intervals / 701080 frames for the recorded case, at 44100 Hz stereo.
The default report/profile/audio stays byte-exact to the prior track checkpoint;
the new step workflow also replays byte-exactly. These are authored pulse-tone
auditions of explicitly chosen quarters, not learned voices or listening acceptance.

The refreshed [core/WFC packages](PACKAGING.md#current-api-delivery) retain
83 core units and 25 adapters. All manifests, owned units, examples and journal
workflows pass. An extracted core consumer passes the full clock/admission
fixture; an extracted WFC consumer saves/reloads the authored step context and
reproduces all three workspace artifacts byte-for-byte. Evidence is under
`build/clock-context-adoption/`. The maintained build includes this context path;
this checkpoint uses focused checks, not a new full clean-source build or Linux
run. Root branch/index/HEAD and vendor sources remain unchanged.

The milestones remove this completed explicit-admission bridge from remaining
work. Automatic arrangement/rate/unknown competition, early switches, endpoints,
metrical meaning and local-key calibration remain open. Completion stays at
55.5 weighted points across 22 unfinished outcomes; the bridge clears a consumer
integration step without satisfying independent musical accuracy. All three
genre styles remain unaccepted and synthesis listening feedback is pending.

## Previous checkpoint — selected-clock API — 2026-09-20

The [selected-pulse clock API](BEAT-TRACKING.md#selected-clock-api) is now maintained
in `src/pythian.beat.clock.pas`. `ReconstructBeatClock` accepts detached scalar
owner/support windows with explicit pulse choices, gaps and restarts. Linear and
step-capable shapes retain segments, residuals, raw/aligned points and observation
indices. No tracker/WAV/WFC dependency enters this unit. The track unit exposes
`SelectedBeatClockWindows` for its explicit selection; it does not change the
selection algorithm. Bounds are 512 windows / 1024 segments / 8192 observations /
65536 preflighted candidate crossings. Invalid calls preserve assigned results.

The native beat operator exposes `--track --clock linear|step`, adds a
`continuous_clock` section to its current report and routes auditions to that
explicit shape. Existing source/measurement/track fields replay exactly. Without
the flag, behavior is unchanged. The maintained build includes focused clock
fixtures and an authored changed-tempo clock audition. No new format version,
learner dependency or automatic metrical admission is introduced.

All six development sources, both frozen paths and both shapes reproduce every
study clock field exactly through the final API. The experimental joint selector
remains outside maintained code; its combined .943396 doubling / .948718
acceleration scores are parity evidence, not claims about default tool selection.
Clock and existing track/context fixtures pass checked stable Win32/Win64 and
trunk Win32. Public boundary checks cover work limits, ownership, nonfinite/
malformed inputs, conversion, numeric phase ambiguity and gap/restart alignment.
An additional rejected-phase counterexample exposed an alignment leak; it is
retained, fixed and passes on all three targets. Final six-source parity and the
changed native tool/listening path pass again after that fix. Audio reopens with
bound hashes, source geometry and no clipping; no listening verdict is claimed.

[Current packages](PACKAGING.md#current-api-delivery) now contain 83 core units and
25 WFC adapters. Final core Win32 and WFC Win64 ZIP manifests, complete owned-unit
closure, examples and journal workflows pass. External clock fixtures compile
and run using only each extracted core directory, including the rejected-span
case. Final deliveries are `build/beat-clock-adoption/final-core/` and `final-wfc/`;
earlier package directories in that evidence folder are superseded. The previous
full clean-source integration snapshot predates this addition; no new full-suite
or Linux/remote-CI claim is made. Root branch/index/HEAD and vendor sources remain
unchanged. Final clock unit SHA256:
`6375d43ee3aa3dfd57cab2c1bae9c4b02c30957ca6d323197e8deca14fc065bb`.

Next context work can connect these explicit selected-clock ranges to saved
context and actual WFC while preserving gaps, ambiguity and caller-owned quarter
meaning; the existing admission consumer still takes the earlier track type.
Automatic pulse work must resolve arrangement/rate/unknown competition, early
switch timing, endpoints and metrical alternatives before independent admission.
The milestones remove completed API adoption from active work and link its
remaining integration to CONTEXT/PULSE. Full scope stays active: 22 unfinished
outcomes, 55.5 weighted points, all three genre styles unaccepted and synthesis
listening feedback pending.

## Previous checkpoint — continuous clock study — 2026-09-20

The [continuous-clock experiment](BEAT-TRACKING.md#continuous-clock) freezes the
baseline and joint-selected candidates and changes reconstruction only. Owner-
center phases are unwrapped, missing candidates break the clock, and monotone
phase segments render one sequence of beat crossings. A separately declared
step-capable alternative solves an interior switch from endpoint rates/phases;
when infeasible it retains linear phase. Feasible interpolation is not a musical
change detector. All six inputs are the same development WAVs; no annotation
enters inference and no held-out recording is used.

On joint-selected paths, final aligned 30-ms F1 is .963855 / .943396 / .948718
for stable arpeggio / doubling / acceleration; all three authored cases remain 1.
The acceleration regression is removed: 37 matches, one extra, three misses.
Doubling keeps 25 / two / one. Early doubling switch placement, initial/final
coverage and the arrangement role-pattern counterexample remain unresolved.
Plain linear phase alone smears the exact abrupt control by 167 ms and lowers
recorded doubling to .905660; endpoint-constrained steps restore both. Both
variants keep the analytic acceleration error within 23 ms. Baseline-selected
acceleration benefits from linear phase but not the step alternative, so the
representation and selection must be evaluated together.

Focused controls cover exact constant/piecewise phase, frame rounding, owners,
missing-window gaps, numeric ambiguity, rejected stalled intervals, infeasible
steps and replay. An initial half-frame numerical fault is retained and fixed
before WAV runs with a declared scale-aware rounding guard. Full original linear
reports replay through the step-capable implementation. An initial-anchor
initialization removes a compiler warning; final acceleration replay is exact
except elapsed time. Native cue overlays for doubling/acceleration reopen with
bound hashes, unchanged source geometry and no clipping; no listening verdict is
claimed. Final checked stable Win64 programs have no warnings or unfreed blocks.

Artifacts, native programs, policies, original failures, reports and listening
WAVs are ignored under `build/beat-continuous-clock/`. Original policy SHA256:
`d52fc5411684fdec93dc6640ba6f0f413e41ddb87094d6c6b2ed0f958bff3c7b`;
step declaration SHA256:
`b7e4913cd47251fb77b33b397c8a54c4732651a9dc9d875e85676a0f875b2fb5`.

Next PULSE work should adopt this representation at a small bounded native API
for selected pulse hypotheses, preserving shape alternatives, raw evidence and
gaps. Automatic admission still requires meaningful arrangement/rate/unknown
competition, change timing, endpoint/metrical accuracy and independent evaluation.
No maintained default, format or dependency changes this turn. The full objective
remains active, with 22 unfinished outcomes and 55.5 weighted points; synthesis
listening feedback remains pending.

## Previous checkpoint — joint timing paths — 2026-09-20

The [joint timing path experiment](BEAT-TRACKING.md#joint-timing-path) now evaluates
complete beat positions rather than descriptor maxima. Fixed unit-weight rate /
unchanged-pattern / unknown potentials use the previous signed joint measurements
and retain bounded multi-window histories. Actual native source onsets/candidate
sets, rendering and alignment reproduce the baseline exactly before selection.
No annotations enter inference and no held-out recording is used.

On the same six development WAVs, abrupt 75→150 aligned F1 improves from .847458
to .943396: 25 matches, two extras, one miss. The first five owner windows now use
about 75 BPM. Stable arpeggio and all three authored paths stay unchanged.
Acceleration regresses from .897436 to .875000: 35 matches, five extras, five
misses, two seam issues. The arrangement feature counterexample still receives a
positive rate bonus .111103843, versus .999934589 for true doubling. The policy is
therefore not adopted; useful relative evidence alone does not establish a clock.

The 32- and 128-history-per-ending-candidate searches select identical full paths,
phases, hypotheses, scores and raw/aligned frames. Zero joint weight reproduces the
existing exact ratio-2 dynamic program; merely permitting doubling changes none
of the six baselines. Repeated inference is exact. Independent ordered matching
confirms all scores. Checked stable Win64 programs have no compiler warnings or
unfreed blocks. At most 117224 candidate extensions occur per search; upstream
recurrence work remains separately accounted. Native sources, policies, full
paths, numerical controls and scored error times are ignored under
`build/beat-joint-path/`. Policy SHA256:
`302f3065fc6f727ddc9fc16e331f76af392257153f4ce458036f8dc64379a812`.

Next PULSE work must join continuous clock/phase and change timing with meaningful
arrangement-change alternatives and unknown evidence. Respect the six-second
measurement interval and correlated comparisons; test stable instrumentation,
true doubling, the role-pattern counterexample and acceleration together. Do not
substitute a weight sweep or larger beam for these missing semantics. Automatic
context and held-out admission remain open. No maintained API, estimator default,
format, dependency or listening verdict changes. The active backlog remains 22
unfinished outcomes and 55.5 weighted points; the full objective remains active.

## Previous checkpoint — joint band recurrence — 2026-09-20

The [joint band recurrence study](BEAT-TRACKING.md#joint-band-recurrence) retains
all nine signed ordered band-pair lag relationships and their component scores.
It distinguishes the previous feature-level ambiguity: true doubling scores
.999934589, while unchanged-clock role-pattern change scores .111103843 with four
opposing pairs. Diagonal-only evidence remains identical. Known periods, an
independent asymmetric integer-moment oracle, gain/DC invariance, quiet/silent
band accounting, short/flat unknowns and unchanged fast accents pass.

The span-bound constant control exposed spurious variance from ordinary prefix
sums. Compensated values/squares/cross-products fix it without musical threshold
changes. Initial source results, unit and failure log are retained; a numeric-fix
declaration precedes all six corrected source reruns. Final diagonal comparisons
against the old two-pass method differ by at most about 3.24e-12, with no
availability changes. Corrected abrupt-source replay is exact except elapsed time.
All checked stable Win64 final programs have no warnings or unfreed blocks.

The same three development WAVs and three authored cases retain useful relative-
rate evidence. The 75→150 source prefers scale .5 across windows 6–10; at window 9,
joint similarity is .609859 versus .300803 for unchanged scale, with all nine
components positive. Every acceleration comparison now prefers a shorter period,
although neighboring rate alternatives can be close. Stable clocks retain scale 1;
the authored 120→100 change retains 1.189207, nearest 1.2 on the declared grid.
Early arpeggio instrument additions oppose one component despite unchanged tempo,
so a blanket sign veto would also be wrong. Similarities are not confidence.

The next PULSE result must use this representation in an explicit arrangement/
rate/unknown decision policy and evaluate full beat paths, phase and metrical
alternatives. Merely retaining more measurements does not clear automatic context.
Joint correlation work stays below 64 million visits per source; prefix work and
old-method audit work are separately reported. Local full runs take about 2.5–3.4
seconds, without a many-hour or realtime claim. Evidence is ignored under
`build/beat-joint-recurrence/`. Policy SHA256 is
`ec459a3a4cfe0381a97a39d9ec329d540bb20ab055b89e4f6f4ac337dfd30c1b`;
the numeric-fix declaration is bound in each final report.

Maintained beat paths/F1, production APIs, dependencies, formats and held-out split
remain unchanged. No listening verdict or completion credit is added; 22 outcomes
remain open at 55.5 weighted points. Register/presence work and corpus preparation
remain independently actionable. The requested listening preview awaits feedback.

## Previous checkpoint — temporal band recurrence — 2026-09-20

The [temporal band recurrence study](BEAT-TRACKING.md#temporal-band-recurrence)
finds useful relative-pattern rate evidence without changing beat inference.
Continuous band flux from the existing native FFT feeds bounded per-band lag
correlations; adjacent and separate-window comparisons retain all 25 rate
alternatives. The existing 75→150 BPM source prefers period scale .5 across
windows spanning the change (representative similarity .815684 versus .659270
for unchanged scale). The stable arpeggio and regular/polyphonic authored clocks
retain scale 1; the authored 120→100 change selects 1.189207, nearest the 1.2
reference ratio on the declared grid. The accelerating recording has mixed,
lower-similarity evidence and is not promoted to a trustworthy tempo trajectory.

Known-period, independent integer-moment, gain/DC, rate-doubling, unchanged-fast-
accent, flat/short and absolute-level ambiguity controls pass. A separately
predeclared counterexample then finds an important limit: true doubling and an
unchanged-clock change from alternating to simultaneous band identity produce
per-band curves equal within about 1e-15, both with .999927974 scale-.5 similarity.
Their joint band timing differs. Independent-band recurrence therefore cannot
admit a tempo change, even with a high similarity threshold. The next PULSE
representation must retain that relationship or other discriminating context,
alongside explicit uncertainty. This replaces a vague request for more band
information with a concrete missing relationship and a retained counterexample.

All six declared WAV measurements and controlled checks finish on checked stable
Win64, with source/report binding, bounded correlation work and no unfreed blocks.
An initial managed-result warning is fixed; final builds have no warnings. The
abrupt-change report replays exactly except elapsed time after the preflight fix.
Evidence and Pascal sources are ignored under `build/beat-band-recurrence/`;
original measurement policy SHA256 is
`f55d50702d55503687a10874f77e2499c02660e3bc482f9149dd2ceae6d54287`.
No new recordings, held-out use, model, production dependency, public format or
maintained inference changes. Original beat F1 stays .9639 / .8475 / .8974;
all 22 outcomes and 55.5 weighted completion points remain unchanged. The listening
preview still awaits observations. Register/presence work remains open in parallel
with this independently actionable base-context requirement.

## Previous checkpoint — full-capacity pitch comparison — 2026-09-20

The [full-capacity pitch comparison](PHRASE-EVALUATION.md#full-capacity-comparison)
rejects the tested larger-model drop-in replacement. With the unchanged preferred
entry/activity/event decoder, full-model precision is 90.6203% flute / 96.6887%
violin, below 98% on both recordings. Coverage improves to 86.8536% / 93.4026%,
and violin full-note F1 improves to .927374, but wrong-pitch and reference-rest
admissions increase. One hundred flute centers retain the exact same wrong pitch.
The actual synthetic source still loses its 30-ms 55-Hz note; the existing
six-note checker records failure rather than relaxing expectations.

The official full weights and source are pinned; all 38 float32 tensors (88977312
bytes) match independent native HDF5 extraction. The existing Pascal TensorFlow
2.18.1 CPU C-API graph executes the reference model; no Python is executed and
no production dependency is introduced. Known-frequency/gain/DC controls pass;
weak/missing-fundamental and silence/quiet diagnostics remain explicit. Both
original tiny caches replay the generalized decoder's decisions and measurements
exactly. Source-bound independent scores and paired accounting reconcile all
2997 centers per recording. Measurement takes 90.296 / 90.250 seconds per
30-second excerpt on this local reference runtime, not a native port benchmark.

Evidence, pinned inputs/notices and source/logs are ignored under
`build/crepe-full-comparison/`. Final checked Win64 runs show no owned compiler
warnings or unfreed blocks. Initial function-pointer binding and replay-path
errors were corrected; failure logs are retained. The declared policy hash is
`99a2c159192be591bdb4b4c4d9e82e8c7130cae707bd1a085ed31b1a99a901e1`.

Keep the preferred baseline and held-out material untouched. A larger native
model port is not justified by this drop-in result; pitch-identity/presence
observations or calibrated policies must first demonstrate the missing accuracy
without losing short/quiet notes or real octave changes. Related-model agreement
is not independent correctness evidence. The milestone rows now record this
constraint. All 22 outcomes remain unfinished, overall credit remains 55.5,
and the requested synthesis preview still awaits listener observations.

## Previous checkpoint — current API delivery — 2026-09-20

The [current API delivery](PACKAGING.md#current-api-delivery) closes the stale
package gap. Fresh core/WFC ZIPs contain 82 core units and 25 optional adapters,
including the later spectral/pitch queries, phase-aware fitting, automation work
correction, transactional/mapped layer edits, preferences and owned saved-grid API.
The packaged README describes those contracts. Core has 92 files/five examples;
WFC has 221 files/seven examples plus the journal operator and helper closure.
All 91/220 content hashes and manifests pass fresh extraction checks, followed
by every owned unit build and packaged example run on stable Win32/core and
stable Win64/WFC. The packaged journal blend/reblend/context replay also passes.

External source/pitch/spectrum fixtures pass against the core extraction; named
layer and saved-style fixtures pass against the WFC extraction. The existing
voice operator compiles solely against package sources. Base/preferred grid
checks, typed pitch edits, independent output checks and coupled edit controls
pass. Preferred and locked renders each produce 705600 stereo frames / 120 notes;
all eight WAV/JSON/MIDI/preview artifacts exactly replay the prior grid checkpoint.
These are numerical and consumer checks, not listening or genre acceptance.

An isolated 301-owned-file source snapshot at
`5231371804cfd7cf8466d256c42f9bad3bafbd85` has a fresh clone with both pinned
submodules fetched from their declared remotes. All owned snapshot bytes and the
82/107 delivered units match the source at capture. The complete maintained
`tools/build.ps1` passes on checked stable FPC 3.2.2 i386-win32 from that clone,
including the newer APIs and all generated native learning/archive workflows.
No owned-source warnings are reported; existing WFC/RTL warnings remain. This is
not a complete three-target suite. Root HEAD/index/hello-pythian are preserved;
only the ignored verification snapshot has a local commit. Documentation records
are updated after source capture.

The first directory name collided with an older ignored delivery record. Its
new core package passed and was relocated intact to the fresh delivery directory.
That attempt replaced the historical core-package log and appended an invocation
failure to its snapshot log; old ZIPs/checkout were untouched. The artifact/path
record identifies this precisely. Current evidence is bound to the new hashes,
not inferred from those historical log names.

The read-only WSL probe still returns help and exit code 1. Linux/remote CI,
independent downstream use and future accepted musical-workflow delivery remain
open. The backlog now contains those remaining delivery requirements rather than
the completed package refresh. NS-6 stays at 50% and the full goal at 55.5 weighted
points / 22 unfinished outcomes: refreshing previously credited delivery does not
earn musical or independent-adoption credit. Return to WAV register/presence work;
its existing failures and held-out policy remain unchanged.

Evidence is ignored under `build/delivery-api-refresh/`: current ZIPs, extracted
consumer logs, exact replay hashes, source manifest, snapshot revision, complete
build result, Linux probe and preserved root-state checks. The production code,
dependency revisions and native formats are unchanged.

Final verification confirms a clean checkout, unchanged 301 snapshot files and
unchanged root HEAD/index/branch. Documentation checks resolve 1668 local links
in 65 documents with zero errors, including package README/provenance in their
actual extracted locations. The initial source-template check expected LICENSE
beside packaging/README.md; that link resolves in the delivered package instead.
The final ledger binds current ZIPs, source manifest, consumer/full-build logs,
replay hashes and updated documentation.

## Previous checkpoint — companion-part diagnosis, 2026-09-20

The [companion-part diagnostic](PHRASE-EVALUATION.md#companion-ownership-checkpoint)
rules out simple simultaneous companion-note capture as the explanation for the
current flute register failures. All 105 octave-error centers have zero exact or
pitch-class matches to the aligned violin reference; thirteen occur during its
reference rests. The other seven wrong flute pitches also have no match. Only
three of 45 flute false-rest admissions exactly match the companion. Violin's
nine wrong pitches and 23 false-rest admissions have no exact flute-reference
match. Correct/unison cases remain in the same complete reports.

Both parts' note files are independently parsed and all 2997 reference labels per
direction replay exactly against source-bound preferred scores. All correct,
wrong/octave/rest counts reconcile; complete per-center results and contiguous
error runs are retained. No reference enters inference. This does not prove
acoustic independence, identify the origin of the octave-related partials, or
exclude all leakage/unannotated activity. No separation shortcut is justified.

The next register/presence model still needs richer target-recording evidence
and explicit ambiguity, preserving articulation, weak-fundamental and short-note
controls. General mixed-part admission does not become a new blocker for this
isolated-recording work. REGISTER/BOUNDARIES still block phrase freeze; accepted
inference, scores, held-out material and the 55.5-point / 22-outcome assessment
remain unchanged. No listening or genre-style acceptance is claimed.

Checked stable Win64 diagnostic builds have no warnings; both final runs report
zero Pascal heap leaks. A first accounting assertion used wrong score-field names
and rejected before publishing a report; the corrected names match the existing
scorer. Policy, native source, complete reports and terminal logs are ignored under
`build/phrase-companion-ownership/`. There is no maintained API, format, dependency,
package, branch or index change.

Documentation validation resolves 1672 local links across 61 documents with zero
errors. The ignored checkpoint ledger binds the diagnostic/policy, original source
and reference identities, preferred score inputs, terminal logs and documentation.

## Previous checkpoint — coherent short-note hybrid, 2026-09-20

The [coherent-support actual-estimator hybrid](PHRASE-EVALUATION.md#coherent-cycle-hybrid-checkpoint)
passes the prior waveform controls and recovers all six authored synthetic notes,
including the missing 30-ms 55-Hz event. One shared fit over the claimed source
span rejects the two-tone counterexample: local residual 0.000517169 versus
whole-span residual 0.999230511. Existing fit, activity, temporal and admission
thresholds remain unchanged. Original actual-estimator states and intervals
replay exactly before adding the declared experimental 0.95 hypothesis support.
A native independent check verifies synthetic identity/count, timing and real gaps.

The same frozen condition reaches recorded evaluation but supplies only 2/0
available/applied observations for flute and 6/2 for violin. Independent scoring
and paired accounting confirm zero changed frame classifications and unchanged
aggregate metrics: precision 91.572732% / 98.552036%, coverage 82.455292% / 87.085166%.
Flute still fails the 98% gate; violin retains its four development passes.
No replacement is adopted, and held-out material remains unused. Short-note
feasibility is established for the tested synthetic scope, not general recorded
admission or calibrated probability.

Next address coherent harmonic/changing recorded sound, competing pitch identities
and explicit presence/rest ambiguity, preserving the passing short/quiet/gap/mixture
controls. More near-sinusoidal residual/support tuning is not justified by this
result. REGISTER and BOUNDARIES still block phrase freeze; WAV-VALIDATION owns
adoption/calibration/cost. The full goal remains active at 55.5 weighted points
and 22 unfinished outcomes; no listening or genre-style acceptance is inferred.

Study policy, native sources, caches/reports and logs are ignored under
`build/cycle-coherent-support/`. Successful checked stable Win64 builds have no
warnings, and completed controls, hybrid, independent synthetic check, compact
report projection, scoring and paired runs report zero Pascal heap leaks.
A wrong policy argument and oversized scorer inputs reject first; their logs
retain runtime exception allocations. Corrected invocations succeed without
changing input binding or scorer limits. The compact reports omit only observation
arrays and bind their full originals by hash. No maintained library, format,
dependency, package, branch or index change is made.

Documentation validation resolves 1667 local links across 61 documents with zero
errors. The ignored checkpoint ledger binds policies, native sources, original
model/cache identities, baseline and final reports, terminal logs and documentation.

## Previous checkpoint — milestone reassessment, 2026-09-20

Reassessed the full goal and rewrote the [milestone plan](MILESTONES.md#north-star-assessment)
against PROJECT.md, the supported fundamentals review, layered-style requirements,
current public source limits, musical evaluation evidence and package gaps.
The retired 89.8% remains unsupported. The goal-level allocation remains
**55.5 weighted points (approximately 55%)**, with **22 unfinished outcomes**:
foundation 100%, fundamentals 80%, WAV learning 30%, WFC composition/reuse 70%,
corpus/style quality 25%, delivery/independent use 50%. All three genre styles
remain unaccepted. This is planning judgment, not measured test coverage.

Completed capabilities are condensed into the six goal rows; the active backlog
contains only remaining work with one primary owner, dependencies and closing
criteria. Removed repeated status/accounting prose and retained existing item
anchors. Explicit scope mapping covers base key/BPM, bass/voice and relationships,
granular dependent passes, saved blend/reblend, many-hour corpus balance/scale,
structure, practical native inference and independently usable delivery. No new
unowned requirement was found; unresolved decisions remain assigned to those rows.

The next five substantial milestones carry 32 conditional overall points:
quality +5; reliable notes/context +6.25; parts/relationships +11.25; semantic
styles/generation +4.5; first accepted style +5. All-three-style/cross-style
acceptance adds the remaining 10, and delivery/independent use 2.5. No experiment
count earns those points. Scope and required acceptance must remain explicit.

The review also reconciles the previously unrecorded
[refined-cycle mixture failure](PHRASE-EVALUATION.md#refined-cycle-support-checkpoint)
from existing ignored sources and terminal logs. Refinement clears the gate-tail
control but admits about 280 Hz from a 220 + 331 Hz mixture. Actual hybrid and
recorded evaluation remain unexecuted for that condition. Coherent observation
support and ambiguity remain under BOUNDARIES with REGISTER/VALIDATION; no provider
is adopted. The current pulse ranking limitation is explicit in PULSE as well.

This checkpoint changes documentation only. No new analysis, acquisition, native
build, package verification or listening acceptance was performed. Existing
source/model evidence is reused within its recorded scope.

Validation: 1663 local links across 61 documents resolve with zero errors.
Reviewed the 22-row ownership count, dependency links and complete 100-point
allocation. Changed documentation contains no private WAV-source origins.

## Previous checkpoint — low-short-note admission, 2026-09-20

The [native low-short-note trace and cycle experiment](PHRASE-EVALUATION.md#short-note-admission-checkpoint)
locate the missing 55-Hz event before final admission. Expected-pitch support peaks
at 0.345235, while the period-local floor is active and entry scale reaches 1.
Every latent state stays unknown; no short/support/tuning rejection occurs.
All original cached native inference states and intervals replay exactly.

A separate native crossing/sinusoid-fit observation was implemented under a
predeclared policy, without relaxing model or event thresholds. Its whole-window
condition fails the first short-low-note control. A cycle-local support revision
recovers 16 phased short-note controls, then fails the next identity check: a
55-Hz gated tail yields 56.764069 Hz with residual power only 0.003157324. A paired
same-phase diagnostic shows the same result before/after gain and DC changes.
Thus low fit residual can coexist with a gate-truncated period and wrong frequency.
The diagnostic's one final event does not clear the observation failure.

Execution stops before later quiet/gap/silence/counterexample controls, the actual
cached-model hybrid and recorded scoring. Next distinguish complete periodic
support from gate edges, with frequency refinement/uncertainty and explicit active
regions before combining evidence. Preserve the new phased/gated-tail cases and
the original recorded gates. The existing multi-harmonic fitter is unchanged;
no threshold sweep or held-out input is used. Preferred inference and scores remain
unchanged. The full goal stays active at **55.5 points / 22 unfinished outcomes**.

Checked stable Win64 builds have no warnings; the failure diagnostic has one
unused-constant compiler note. Trace replay and paired failure diagnosis complete;
both control conditions fail as recorded. Runs report no Pascal heap leaks.
Policies, initial/revised native sources, trace, controls and logs remain ignored
under `build/short-note-admission/`. There is no maintained library, format,
dependency, package, listening verdict, branch or index change.

Documentation validation resolves **1719 local links across 61 documents with
zero errors**. The ignored checkpoint ledger binds policies, initial/revised code,
input identities, trace/control/failure logs and the updated work/milestone evidence.

## Previous checkpoint — waveform-qualified event context, 2026-09-20

The [waveform-qualified event-context comparison](PHRASE-EVALUATION.md#note-context-checkpoint)
is implemented and measured. Native source-timed attack anchors replace independent
learned-onset peak cuts while retaining note labels/admission. Focused controls
preserve delayed attack confirmation, repeated notes, quiet short notes, gaps and
silence; the original direct-head events replay exactly. Flute/violin scored event
counts fall from 169/135 to 112/94. Full-note F1 improves to 0.7826/0.8962, but
precision remains failing at 81.40%/91.11%, with 216/178 false-rest centers. Four
independent paired comparisons reconcile the condition against direct-head and
preferred period-entry results. No replacement is adopted.

The short-note fallback was checked through the actual native CREPE estimator,
not constructed salience. Its 398 windows over the existing four-second synthetic
WAV take 66.563 seconds. The unchanged period-entry path recovers the short 440-Hz
note, quiet sustain and a real gap, but still misses the 30-ms 55-Hz note. Earlier
floor controls remain valid for their declared support; they do not establish
end-to-end estimator recovery. The new low-note failure still needs localization
at raw support, latent decoding and final admission. No model fusion is claimed.

Next retain useful source-timed event identity and address presence/rest and
register evidence together. Establish the actual short-note support path before
claiming a fallback, then declare the combined observation contract before another
scored candidate. Do not exchange required precision for better event F1 or revisit
unconditional onset cuts. Preferred inference, held-out split and all admission
gates remain unchanged. The full goal stays active at **55.5 points / 22 outcomes**;
no listening or multi-recording style acceptance is claimed.

Checked stable Win64 builds and focused controls, native measurement/inference,
source/query replay, scoring and paired accounting finish without compiler warnings
or reported Pascal leaks. Existing raw-head audit evidence is reused; no new full
independent decoder audit is claimed. Policy, native study unit/operators, caches,
reports and terminal logs remain ignored under `build/note-context/`. Maintained
library code, formats, dependency source, packages, branch and index are unchanged.

Documentation validation resolves **1717 local links across 61 documents with
zero errors**. The ignored checkpoint ledger binds policy, study sources, reused
estimator/observation units, source-bound reports, terminal logs and updated records.

## Previous checkpoint — note-head support diagnosis, 2026-09-20

The [note-head support/onset diagnosis](PHRASE-EVALUATION.md#note-head-support-diagnosis)
is complete. Both authored 30-ms notes lack expected-pitch support before the
minimum-length filter: raw peaks remain 0.135161/0.189116 over fixed ±100-ms margins,
below 0.3. Temporal smoothing or a length-filter change alone does not repair this
condition. Quiet 220-Hz sustain has note support 0.716450 but onset support only
0.109118 on the scoring grid, so a mandatory strong-onset gate is also unsupported.

Of 91/83 same-note cuts, 49/66 lie near changed-pitch attacks; 6/13 lie near repeated
pitch attacks. Correct-pitch interiors account for 19/4, reference rests 11/0 and
other activity 6/0. Raw onset peaks cover 12/14 flute and 13/13 violin repeated-pitch
references; interpolation retains 11/14 and 13/13. These are diagnostic coverage
counts, including excerpt-edge notes, not new onset F1 scores. Every cut total
reconciles with the preceding independent audit.

Next implement a declared event-context observation contract: an onset may confirm
an existing pitch attack or support a repeated event, without forcing both to be
new notes. Preserve optional onset evidence for weak attacks, explicit unknowns
and independent support for short notes. Qualify that contract with the existing
short/quiet/gap/repeated-note controls and unchanged paired recorded gates before
adoption. Register and source-head limitations remain open; no production model
port is justified by this diagnostic. Preferred inference and all scores remain
unchanged. The full goal stays active at **55.5 points / 22 unfinished outcomes**.

Checked stable Win64 native builds/runs have no warnings or reported Pascal leaks.
The corrected diagnostic reports raw and interpolated peak coverage separately;
initial source/results are preserved. Source/policy/audit/reference-bound reports
and logs are ignored under `build/note-head-diagnosis/`. No network, held-out use,
new estimator run, maintained library/format change, listening verdict or package
change occurs. Branch, index and dependency source remain unchanged.

Documentation validation resolves **1717 local links across 61 documents with
zero errors**. The ignored checkpoint ledger binds policies, initial/corrected
sources, reports, terminal logs, input audit identities and updated records.

## Previous checkpoint — recorded note/onset comparison, 2026-09-20

The [separate note/onset recorded comparison](PHRASE-EVALUATION.md#note-head-recorded-checkpoint)
and independent native cache/event audit are complete. The declared direct decoder
is rejected as a replacement: flute/violin coverage rises to 86.32%/96.76%, but
precision falls to 82.11%/91.70%; both fail the unchanged gate. False-rest admissions
rise from 45/23 to 194/167, and scored event counts rise from 95/86 to 169/135.
Flute onset/full-note F1 falls to 0.6288/0.5758; violin reaches 0.7946/0.7500.
Paired accounting finds 127/261 correct-center gains with 47/19 losses. Existing
period-aware entry inference remains preferred.

The audit binds original sources, model, policy and code, verifies all retained
heads against raw windows, independently reconstructs nonuniform source timing,
interpolation and source RMS, and reproduces every interval without calling the
comparison decoder. It passes for both recordings and the earlier synthetic case.
Geometry/constructed-head controls do not erase the two missed 30-ms waveform
notes or the quiet/low-note timing defects. This is policy-execution evidence,
not native-model numerical fidelity or calibrated confidence.

Next distinguish short-note head support from decoder suppression and qualify
onset evidence at repeated notes versus within existing attacks/sustains. Use that
evidence to declare a temporal observation contract before another scored candidate;
do not port the current failing policy into production or sweep thresholds. The
register/boundary gates, held-out split and applicable validation requirements stay
unchanged. No listening verdict or multi-recording style acceptance is claimed.
Engineering completion remains **55.5 weighted points / 22 open outcomes**; the
full goal remains active.

Checked stable Win64 compilation and native measurement/audit/scoring/paired runs
complete without compiler warnings or reported Pascal heap leaks. Reference-runtime
allocations are outside heap-tracing scope. The two reference-model processes ran
concurrently; their timings are scoped observations. Policies, raw heads, converted
audio, source-bound reports, code and logs remain ignored under
`build/note-head-recordings/`. No maintained library, saved format, dependency
source, held-out evaluation, package, branch or index changes occur.

Documentation validation resolves **1715 local links across 61 documents with
zero errors**. The ignored checkpoint ledger binds the final policy, native study
sources, model/attribution identities, reports, terminal logs and updated records.

## Previous checkpoint — milestone reassessment, 2026-09-20

The [milestones](MILESTONES.md#north-star-assessment) have been rechecked against
full project scope, public core/companion contracts, musical evaluation, corpus
requirements and delivery evidence. Engineering completion remains **55.5 weighted
points**, with goal credits **100/80/30/70/25/50%**. The older 89.8% is retired.
There are **22 unfinished outcomes** and **zero accepted multi-recording styles**
across chillwave, stoner rock and lofi.

The reassessment exposes earned/unfinished allocations within every goal, an
acceptance dashboard and owners for missing evaluation decisions. Provider
accuracy/cost limits, corpus coverage/workload budgets and style/listening rubrics
must be declared before evaluation. Completed capabilities stay at goal level;
active rows contain remaining outcomes, prerequisites and blocking links. M1–M5
own 32 conditional overall points; M6/M7 own the other 12.5. Remaining scope totals
44.5 points without counting provider work again in consumers.

Inspection of existing unfinished-study artifacts adds the
[preliminary note/onset controls](PHRASE-EVALUATION.md#note-head-preliminary-controls)
to the evidence: geometry/decoder controls pass, but the waveform model misses
both authored 30-ms notes. Recorded comparison and independent cache/event audit
remain unfinished. This documentation review claims no new inference, held-out
run, production port, listening verdict or completion credit. The next technical
decision is the declared comparison/audit followed by a representation decision;
all adoption gates remain. Core listening and corpus/protocol preparation are ready.

Validation: the existing native documentation checker resolves **1707 local links
across 61 documents, zero errors**. Goal weights, per-goal allocations, 22 outcome
owners and M1–M7 contributions reconcile. The reviewed changes affect three
documentation files only; no library/build tests were needed. Comparison copies
and the link-check log are ignored under `build/milestone-alignment-refresh/`.
Branch, Git index and dependency source remain unchanged.

## Previous checkpoint — note/onset feasibility, 2026-09-20

The [stationary harmonic-presence condition](PHRASE-EVALUATION.md#harmonic-presence-control-checkpoint)
fails its 30-ms, 55-Hz control: the baseline retains one event and the changed
observation retains none. The four-cycle fit spans roughly 73 ms. Three preceding
controls pass, including quiet low sustain and low-note gaps; execution stops at
the short-note failure before remaining controls or recorded scoring. No threshold
or core fitter contract is weakened. Evidence stays under ignored
`build/phrase-harmonic-presence/`.

The next approach now has a concrete [separate note/onset head probe](PHRASE-EVALUATION.md#note-head-feasibility-checkpoint).
A Pascal program loads the pinned official Basic Pitch SavedModel through the
already verified TensorFlow 2.18.1 CPU C API. It discovers the serving signature
and verifies all finite 0..1 values, expected 172-frame note/onset/contour shapes
and exact same-process replay for silence, a steady 440-Hz sine and interrupted
440-Hz notes. Warm calls take 16..32 ms per roughly two-second window in this small
reference-runtime probe; that is not native Pascal model cost or sustained throughput.

The optional assets/source retain complete upstream LICENSE/NOTICE and recorded
graph/weight hashes under ignored `build/note-head-feasibility/`. No downloaded
Python source is executed. No production dependency, format or library code changes.
The final checked stable Win64 probe build has no warnings; the successful probe
and earlier failed control report zero Pascal heap leaks. Runtime-owned allocation
accounting is not included in that claim.

Next declare and verify resampling, overlapping-window/output timing and note
decoding before comparing the existing development pair. Upstream's roughly
127.7-ms minimum note length cannot silently replace our short-note requirement.
Keep independent scoring and held-out material unchanged; assess musical results
before a native production port. Preferred inference and all recorded scores stay
unchanged. Completion remains **55.5 weighted points / 22 open outcomes**; the goal
is active. Documentation validation resolves **1688 local links across 61 documents
with zero errors**. Ignored ledgers bind both study policies/sources, acquired model
and attribution files, outputs/logs and updated records. Branch/index and dependency
source remain unchanged.

## Previous checkpoint — boundary emission audit, 2026-09-20

The [boundary emission audit](PHRASE-EVALUATION.md#boundary-emission-checkpoint)
reconstructs local note/unknown observations for all admitted centers in the
preferred period-aware entry path. It reuses original raw salience and saved
activity/attack evidence, with independent source/reference/interval accounting.
It changes no inference or score.

Of 45 flute false-rest centers, only nine locally prefer unknown, all in attack1;
all 20 false-rest sustain centers favor a note. For violin, 11 of 23 locally prefer
unknown (seven attack1, four sustain). Correctly admitted centers also sometimes
prefer unknown: 13 flute and 39 violin. Thus an exit-transition relaxation does
not directly address the main flute residual, and a blanket local-unknown veto
would discard valid evidence. Local emissions are not calibrated probabilities
and these counts do not predict a globally re-decoded path.

Next develop and independently validate a note-presence/unknown observation that
addresses these cases while retaining quiet/short notes and legitimate attacks.
Coordinate that observation with register evidence; preserve the existing temporal
model and counterexamples until a paired change supports replacement. Do not
substitute further floor sweeps, blanket trimming or a forced-release shortcut.

Checked stable Win64 compilation and both source-bound runs pass without warnings
or reported leaks. Policy, Pascal audit, per-center reports and logs are ignored
under `build/phrase-boundary-emissions/`. No production code, format, network/model
run, held-out material, listening verdict or delivery change occurs. Completion
remains **55.5 weighted points with 22 unfinished outcomes**; the goal is active.
Documentation validation resolves **1683 local links across 61 documents with
zero errors**. The ignored checkpoint ledger binds policy, source, reports, logs
and updated records. Branch/index and dependency source remain unchanged.

## Previous checkpoint — declared-range comparison, 2026-09-20

The [declared-range spectral comparison](PHRASE-EVALUATION.md#scoped-register-spectrum-checkpoint)
is complete and rejected as a register solution. Its predeclared policy removes
below-55-Hz power from normalization only when no candidate harmonic band overlaps
it. It preserves waveform samples, harmonic numerators, candidates, donor policy,
event boundaries and all other ranking rules. Synthetic contamination improves,
while low-note/weak-fundamental guards and quiet/short/DC availability pass.

All 40 bank sources and both phrases replay the earlier full-range band evidence
within 1e-10. Removed power averages 3.10% across 452 flute windows and 9.00% across
431 violin windows, but all 96/87 event winners match the preceding full-range
bank comparison. The same single flute event recovers 18 centers without losses;
precision remains 92.54%, below the 98% gate. Violin remains at 98.55%. Seven of
eight articulation challenges pass; low violin spiccato still shifts MIDI 55 → 67.
False-rest counts remain 45/23. The preferred period-aware entry baseline is unchanged.

Separate native auditing verifies source/split bindings, geometric guards,
full/scoped feature pairing, independent costs/donors and preserved interval
fields. Existing scoring/paired tools confirm recorded outcomes. Checked stable
Win64 builds/runs have no warnings or reported leaks. Policy, Pascal study sources,
reports and logs remain ignored under `build/scoped-register-spectrum/`.

Next address in-range octave-related structure and articulation transfer rather
than varying the below-range cutoff. Preserve explicit ambiguity and the existing
phase/periodicity counterexamples; do not infer a second source or noise cause
from residual energy alone. Continue false-rest work before combined policy freeze.
No maintained inference, format, held-out evaluation, listening verdict or delivery
changes occur. Completion remains **55.5 weighted points and 22 open outcomes**;
the goal remains active. Documentation validation resolves **1680 local links
across 61 documents with zero errors**. The ignored checkpoint ledger binds study
sources, policy, reports, terminal logs and updated records. Branch/index and
dependency source remain unchanged.

## Previous checkpoint — milestone alignment review, 2026-09-20

The [north-star reassessment](MILESTONES.md#north-star-assessment) was checked
against the current project scope, core/companion contracts, preferred recorded
phrase evidence, long-source requirements and package limitations. It retains
**55.5 weighted points**, with goal credits **100/80/30/70/25/50%**. The old 89.8%
assessment remains retired. No new musical or listening acceptance supports a
higher estimate; no accepted multi-recording model exists for any requested style.

The milestone file now condenses repeated completion rationale, links every
intended result to its backlog owners and removes completed diagnostic details
from the register/boundary task descriptions. All **22 unfinished outcomes** remain
owned and dependency-linked. Automatic musical-provider admission consistently
requires the shared validation contract; manual/controlled inputs permit earlier
development without clearing that acceptance dependency.

The first five major milestones retain **32 conditional points**. Explicit final
milestones now own all-three-style/cross-style acceptance (**10 points**) and
current delivery/independent use (**2.5 points**). Together they account for all
**44.5 remaining points**, without crediting providers again in their consumers.
The immediate implementation deliverable is a combined note-event policy that
clears development gates, followed by frozen independent evaluation and maintained
adoption. Residual diagnostics remain supporting work, not standalone milestones.

This reassessment changes documentation only. Existing implementation and evidence
remain as recorded below; no new audio evaluation, package build or held-out run
is claimed. The native documentation checker resolves **1679 local links across
61 documents with zero errors**. Goal weights, remaining allocations and milestone
contributions reconcile; no dependency source or Git index changes were made.

## Latest implementation checkpoint — spectral partition query, 2026-09-20

The portable [spectral partition query](ANALYSIS-WAVE.md#spectral-power-partitions)
is implemented in `pythian.spectrum`. It owns bounded power summaries for selected
bin ranges and complementary gaps, retaining peak locations with explicit scope,
failure and ownership contracts. Callers own frequency/window/pitch interpretation.
The maintained fixture/build path covers conservation, gap geometry, bounds,
peak ties/zeroes and preserved managed results. Checked stable Win32/Win64 and
development Win32 fixtures pass without warnings or reported leaks.

Its [recorded consumer](PHRASE-EVALUATION.md#spectral-partition-checkpoint) measures
all 40 bank sources and 96 flute intervals, reconciling the existing band evidence
over 652 spectra. Reference-upper-octave residuals in the 11 error events lie
mostly below/between bands, with very little above the sixth harmonic. Peaks
include both roughly 16..47-Hz content and octave-related locations near half
and three-halves of the reference frequency. Correct/error cohort ranges overlap;
no new cutoff or causal source attribution is established. Low violin spiccato
remains a distinct harmonic-shape transfer failure.

Next distinguish low-frequency content from octave-related partial structure,
preserving uncertainty about source/part ownership and genuine low-note behavior.
Do not assume a high-pass-only fix or discard all residual energy. Existing
articulation, boundary and phase/coherence evidence remains applicable. The
preferred period-aware entry inference and every musical score are unchanged.

Native measurement/inspection runs pass on stable Win64 with no reported leaks.
Evidence, policies and study sources are ignored under `build/spectral-partition/`;
the public unit and its focused fixture are maintained. No new format, estimator
network run or held-out evaluation occurs. Current-source package refresh now
includes the new unit; no complete build/package or new listening verdict is
claimed. The goal remains active at 55.5 weighted points and 22 unfinished outcomes.
Documentation validation resolves **1655 local links across 61 documents with
zero errors**. Final source/test/build, study policy/report and terminal-log
identities are retained in the checkpoint ledger. Branch/index and dependency
source remain unchanged.

## Previous checkpoint — register representation diagnosis, 2026-09-20

The [register representation diagnosis](PHRASE-EVALUATION.md#register-representation-diagnosis)
is complete. All 40 bank sources receive fixed-window prefix/centered periodicity
checks. Both estimators corroborate the failed low violin challenge's nominal
MIDI 55 in all five windows, while separate bank disagreements/unknowns remain
recorded. Cost attribution identifies third/fifth harmonic-shape differences as
the main penalty for that correct candidate; mapped-register coverage alone
does not transfer the sustain template reliably to this articulation.

Every reference-upper-octave candidate in the 11 wrong flute events has its
largest distance contribution in the single outside-band component. That
representation discards where the residual energy lies. The corresponding
periodicity observations support lower/upper/unknown in 71/12/19 cases, accounting
for 102 observations over events containing all 105 lower-octave error centers.
The one valid bank correction also has six lower versus four upper observations,
so a blanket periodicity veto would suppress it. No new rule is fitted.

Next retain residual frequency placement and determine whether below-fundamental,
between-harmonic or higher-frequency content explains the correct/wrong cases
before choosing a background or multiple-component policy. Noise, another voice
and incorrect reference labels are not established by this diagnostic. Preserve
the independent articulation challenge and the separate false-rest work.

Checked stable Win64 builds/runs have no warnings or reported leaks. Source-bound
reports reconcile all stored candidate costs and periodicity categories. Policies,
native study sources and final reports/logs are ignored under
`build/register-bank-diagnosis/`. Maintained inference, formats, scores, listening
acceptance and delivery are unchanged. No network estimator or held-out input is
used. The goal remains active at 55.5 weighted points with 22 unfinished outcomes.
Documentation validation resolves **1646 local links across 61 documents with
zero errors**. The checkpoint ledger retains code/policy/report/log identities;
branch/index and dependency source are unchanged.

## Previous checkpoint — mapped-bank octave comparison, 2026-09-20

The [mapped-bank octave comparison](PHRASE-EVALUATION.md#mapped-bank-ranking-checkpoint)
is complete and rejected as a general replacement. Its policy was fixed before
ranking: six measured bands plus outside-band energy, nearest bracketing mapped
roots of a caller-declared instrument, both dynamics, and no extrapolation or
fitted cutoff. All eight articulation challenges remain outside training. Seven
retain their nominal pitch; low violin spiccato MIDI 55 shifts to 67 despite
matching-register sustain donors being present.

On the period-aware phrase development baseline it changes one flute interval
from MIDI 64 to 76, recovering 18 scored centers and sacrificing none. Flute
precision improves from 91.57% to 92.54%, still below the 98% gate; coverage is
83.33% and full-note F1 is 0.8632. Violin remains unchanged at 98.55% precision,
87.09% coverage and 0.8571 full-note F1. All interval boundaries, tuning and other
fields remain exact; false-rest counts stay 45/23. No recording-specific exception
is adopted, and the preferred development baseline remains period-aware entry.

Checked stable Win64 controls, ranking, existing independent scoring/paired tools
and a separate donor/cost/binding audit pass with no compiler warnings or reported
leaks. Independent cost checks use unit-vector inner products rather than the
ranking's squared-coordinate differences. Evidence, policy and native study
sources remain ignored under `build/register-bank-ranking/`. No network estimator,
held-out evaluation, maintained code, saved format or delivery changes occur.

The next register action is to distinguish the failed low-note articulation and
remaining flute examples using broader articulation/domain evidence or a changed
representation before another phrase policy. Matching nominal register alone is
insufficient; do not repeat donor ordering/cutoff variations or hard-code the one
improved interval. Remaining boundary work proceeds under its separate owner.
Overall completion remains 55.5 weighted points with 22 unfinished outcomes.
Documentation validation resolves **1644 local links across 61 documents with
zero errors**. Checkpoint hashes bind the study policy, native sources, outputs,
scores, audit logs and updated records. Branch/index and dependency source remain
unchanged.

## Previous checkpoint — mapped register reference bank, 2026-09-20

The [independent register reference bank](PHRASE-EVALUATION.md#register-reference-bank-checkpoint)
is measured and audited: 32 mapped sustain sources at soft/loud dynamics plus
eight separate articulation challenges. It supplies the low/high-register
examples missing from earlier local-donor comparisons. The sources come from
the already attributed sample library and remain ignored; their nominal MIDI
identities and tuning are retained from pinned mappings.

All 40 sources yield nominal profiles and 200 active-window spectra. Sustain
shape coverage spans 90.92..99.93% for flute and 30.62..99.05% for violin. Three
flute staccato windows fail the existing shape-coverage rule; their raw energy
remains available. Thirteen upper-octave alternatives fall outside the unchanged
frequency range, and four more have no admitted shape. Missing alternatives
cannot be treated as evidence for a preferred octave. Low violin captured energy
varies substantially with dynamics, ruling out an assumption of uniformly high
six-band coverage without establishing a replacement confidence policy.

Checked stable Win64 measurement and independent source/conversion/activity
audits pass with zero reported leaks and no final compiler warnings. An initial
audit compilation needed named static-array types; measured output and policy
were unchanged. The native spectral function is reused from the prior probe.
Evidence, Pascal study sources and terminal logs are under ignored
`build/register-reference-bank/`; all 40 acquisitions total 85,263,658 bytes.

Next declare a bank-conditioned register comparison, preserve the articulation
split and missing-coverage behavior, and evaluate paired changes against the
preferred period-aware entry path. No ranking, phrase-model rerun or held-out
evaluation occurred here. The separate false-rest gap remains open. Maintained
inference, formats and musical acceptance are unchanged; the goal remains active
at 55.5 weighted points with 22 unfinished outcomes.
Documentation validation resolves **1643 local links across 61 documents with
zero errors**. Source/policy/report and terminal-log hashes are retained in the
checkpoint ledger; branch, index and dependency source are unchanged.

## Previous checkpoint — full milestone reassessment, 2026-09-20

The [full milestone reassessment](MILESTONES.md#north-star-assessment) retains
**55.5 weighted points** across the six north stars: **100/80/30/70/25/50%**.
The retired 89.8% estimate does not represent the intended musical/corpus scope.
Current contracts, source boundaries, phrase evidence and package limits support
the retained credit; no new listening, inference or genre acceptance is claimed.

The active backlog contains **22 unfinished outcomes**, each with a north-star
owner, closing result and linked prerequisites. Completed mechanisms remain in
goal credit and topic evidence. Closing conditions now explicitly include moving
accepted studies into maintained native APIs/consumers, full musical-provider
coverage before semantic workflow acceptance, and separate chillwave, stoner rock
and lofi verdicts. Source/ancestor growth and independent-use requirements retain
their existing owners rather than creating duplicate tasks.

The next five capability milestones now account for core quality, recorded
context/phrases, remaining musical parts/relationships, semantic generation and
reblending, then the first accepted many-recording style. Their conditional
contributions are **5 + 6.25 + 11.25 + 4.5 + 5 = 32 points**, reaching **87.5** only
after acceptance. This replaces the 20.75-point package whose extra provider
prerequisites were outside the sum. The remaining 12.5 points cover broader
corpus/all-three-style acceptance and delivery/independent use. This is a major
roadmap, not a short task estimate. Delivery and corpus preparation remain ready
alongside the primary register/boundary bottleneck.

This checkpoint changes planning/documentation only. No production code, saved
format, dependency, listening verdict or held-out evaluation changes.
The existing native documentation checker resolves **1639 local links across
61 documents with zero errors**. Goal weights, remaining allocations and milestone
contributions reconcile; the active ownership counts remain 0/1/10/3/6/2.

## Latest implementation evidence — period-aware entry activity, 2026-09-20

The [period-aware entry condition](PHRASE-EVALUATION.md#period-entry-activity-checkpoint)
is the preferred development path. Local activity now affects attack/unknown
emissions separately from raw sustain/release support. Its silence floor measures
at least two periods of the raw winning pitch. The same floor threshold remains;
neither graph costs nor recording-specific exceptions were tuned.

Two earlier conditions stopped at controls: wide-mean local RMS bridged a real
gap, while fixed 10-ms local DC removal fragmented a quiet 55-Hz tone. The
period-aware measurement passes 27 control executions, including those failures,
low-note gaps and short notes. Neutral inputs exactly replay the original decoder.
On recordings it restores the preceding all-state condition's lost coverage and
complete matches: flute reaches 82.46% coverage / 91.57% precision / 0.8526 full-note
F1; violin reaches 87.09% / 98.55% / 0.8571. Violin passes all four development gates;
flute still fails precision. It admits more rest pitches than all-state attenuation,
so its retention as a development path does not imply universal improvement.

Independent audits verify raw candidates, period geometry, all activity values,
baseline replay, unchanged attack reports and source/reference-bound paired
scores. The residual audit finds 11 wholly wrong flute events, with 105 lower-
octave errors overall and 45 false-rest centers. Perfect register recovery alone
would still cap precision at 97.58%. Next address whole-event register evidence
and the remaining rest errors while retaining the improved boundary condition.

Final checked stable Win64 builds have no warnings; successful control/recorded
processes have no reported leaks. Earlier failed controls intentionally exit 1.
An initial diagnostic-only Single multiplication mismatch was corrected and the
independent audit rerun; inference and policy stayed unchanged. Evidence, policies
and Pascal study sources are ignored under `build/phrase-entry-activity/`.
No network rerun, held-out input, maintained unit/format or delivery change occurs.
The full inference policy is not frozen or admitted; 22 open outcomes and roughly
55% overall completion remain. Branch/index and dependency source are unchanged.

## Previous checkpoint — center-local activity, 2026-09-20

The [center-local activity condition](PHRASE-EVALUATION.md#local-activity-checkpoint)
is complete. A fixed 10-ms RMS cue scales the unchanged model support relative
to its 64-ms window, retaining the qualified attacks and decoder rules. It removes
46 flute/13 violin false-rest centers without introducing new ones. Violin now
passes all four development gates at 85.25% coverage and 98.61% precision; flute
fails at 79.60%/92.06%. The condition is rejected as a general replacement, with
held-out material still unused and no recording-specific production policy.

The paired audit finds 132/76 correct centers become unknown, one flute correct
center becomes wrong, and seven flute wrong centers become correct. Correct
losses occur mostly in attack/release states, with 22/13 in sustain. Descriptive
early endings increase from 0/7 to 5/9 and full-note matches decline. Next separate
note-entry activity from sustain/release evidence rather than attenuating every
state. Preserve the short/quiet-note and real-rest controls; register errors
remain independently unresolved.

Twenty-three waveform controls pass. Native inference first reproduces all
retained baseline states/intervals/tuning. Final independent audits recompute all
2997 activity measurements per recording, verify unchanged attack reports and
reconcile source/reference-bound scores and paired changes. An initial audit
precision mismatch led to explicit Double arithmetic in the diagnostic clamps
and sums; affected controls/inference/audits were rebuilt and rerun with unchanged
policy and unchanged final musical counts. Final checked stable Win64 builds have
no warnings; terminal processes report zero unfreed blocks.

Evidence and native diagnostic sources remain ignored under
`build/phrase-local-activity/`, with final `*-double-*` reports. No network rerun,
held-out evaluation, maintained implementation, saved format, listening verdict
or delivery change occurred. WAV-03-BOUNDARIES owns the next phase-specific use
of the cue. The 22 open outcomes and roughly 55% overall assessment remain;
branch/index and dependency source are unchanged.

## Previous checkpoint — pitch-conditioned neighboring timbre, 2026-09-20

The [candidate-pitch timbre condition](PHRASE-EVALUATION.md#pitch-conditioned-timbre-checkpoint)
is completed and rejected. It reorders eligible local donors by distance to each
candidate pitch, reusing exact cached spectral vectors and the fixed residual
objective. Flute recovers 110 previously wrong centers and sacrifices three;
violin recovers none and sacrifices 48. Rank-only precision is 94.52%/95.49%,
below the 98% gate. Production inference remains unchanged at 89.14%/97.61%.

Only one flute event differs from the preceding energy condition, losing two
recovered centers. The same short flute and two low violin events remain harmed.
Donor inspection shows that pitch ordering cannot supply absent low-register
examples: one low event has only one donor below MIDI 71, while the other has
none. This rejects this neighbor-selection policy, without claiming that adequately
supported pitch-dependent timbre learning is impossible.

Checked stable Win64 controls, reranking, independent audits and descriptive
comparisons terminate without warnings or reported leaks. Audits verify exact
parent measurements, donor eligibility/order, every residual and all 2997 scored
centers per part. No waveform measurement, network inference or held-out input is
added. Diagnostic Pascal sources, policies, source-bound reports and logs remain
ignored under `build/phrase-timbre-context/`; maintained changes are documentation.

The next implementation direction moves to center-local onset support versus the
wider model window, using the completed rest audit and protecting short/quiet
attacks. Register admission remains open; further timbre work needs suitable
example coverage or different independent evidence. The 22 outcomes and roughly
55% overall estimate remain unchanged. No musical, listening or delivery gate
closes in this checkpoint. Branch/index and dependency source remain unchanged.

## Previous checkpoint — milestone alignment refresh, 2026-09-20

The [milestone reassessment](MILESTONES.md#north-star-assessment) now presents
the six north stars, credited capability and remaining acceptance in one compact
assessment. A fresh comparison with the project scope, supported fundamentals,
current grid API, recorded phrase evidence, style contracts and package limits
supports **100/80/30/70/25/50%**, or **55.5 weighted points**. The former 89.8%
assessment remains retired; this review finds no new accepted musical outcome
that would justify raising the current roughly 55% estimate.

All intended results map to the existing **22 open outcomes**. Completed
extraction, contract review, grid/duration APIs and diagnostics stay in credited
capability and topic evidence. The milestone page removes duplicated rationale
and detailed experiment counts, retaining actionable gaps, acceptance conditions
and linked prerequisites. Corpus scale now identifies the current semantic-style
source/depth/node limits explicitly. Package refresh explicitly includes the new
grid API. Measurement accuracy, composition/reuse, corpus quality and delivery
have separate owners to avoid counting prerequisite work twice.

The next five accepted outcomes still offer **20.75 provisional points**; core
listening and recorded register/boundary admission remain the immediate quality
decision and implementation bottleneck respectively. All three genre verdicts
remain open. This is a documentation review, with no new inference experiment,
listening verdict, held-out evaluation, compiler run or production change.
The native documentation checker resolves **1620 local links across 61 documents
with zero errors**. Branch/index and dependency source remain unchanged.

## Previous checkpoint — neighboring timbre evidence, 2026-09-20

The [neighboring-timbre probe](PHRASE-EVALUATION.md#neighbor-timbre-checkpoint)
tests materially different register evidence against the existing recorded
failures. A declared reference-free comparison of event harmonic shapes with
nearby different-pitch-class events recovers all 127 flute octave-error centers,
but sacrifices 232 correct flute and 409 correct violin centers. It is rejected
as a replacement. Descriptive inspection identifies discarded spectral energy
and differing candidate window sets as concrete confounds.

A second policy, declared before its own execution, retains unexplained spectral
energy and compares candidates on the same windows without a tuned cutoff. It
recovers 112 flute errors while sacrificing three correct centers, giving 94.62%
rank-only precision. Violin sacrifices 48 correct centers and falls to 95.49%.
Both remain rejected under the existing admission criteria. The remaining
counterexamples focus the next hypothesis on pitch/articulation-dependent timbre;
they do not authorize a higher-octave preference or recording-specific shortcut.
Flute's 82 false-rest centers would cap precision at 95.88% even with perfect
register recovery, so boundaries remain an independent prerequisite.

Both policies pass nine pitched waveform controls plus silence. Native measurements
cover 104 flute/91 violin inferred intervals using 468/435 spectra. A separate
audit binds sources, policies, inference/replay, scores and references, recomputes
every one of the 2997 scored centers per part and reconciles the baseline totals.
It independently verifies the second condition's stored energy costs and shared
window counts. Final checked stable Win64 processes are terminal, without compiler
warnings or reported leaks. No network inference or held-out material was used.

All diagnostic implementation, policies and outputs remain ignored under
`build/phrase-timbre-context/`. Maintained changes are observations and linked
backlog direction only. The production decoder, thresholds, formats and musical
acceptance remain unchanged; overall completion stays roughly 55%. WAV-03-REGISTER
now owns sound conditioning for the identified counterexamples, coordinated with
rest-boundary work. This checkpoint supplies evidence for the next decision,
not a new accepted inference capability or a genre verdict.
Documentation validation resolves 1644 local links across 61 documents with zero
errors. The checkpoint ledger binds the native study sources, policies, terminal
logs/reports and updated records; branch and index are unchanged.

## Previous checkpoint — reusable saved grid API, 2026-09-20

The [saved-grid API](GRID-STYLE.md) now moves uniform saved-style provider
construction out of the voice demo into `pythian.wfc.grid`. It owns copied
models/preferences, builds actual named WFC sessions, constructs typed key/tempo/
onset/intensity/pitch and intersected joint masks, analyzes scoped feasibility,
and captures detached native context/musical arrays. Capture validates original
model paths, latent-token agreement and observed joint relationships. No new
solver, file format, fixed PPQ or authored voice policy enters the adapter.

The voice demo consumes this API; its CLI, arrangement, JSON and synthesis remain
tool responsibilities. The existing style fixture adds an independent API caller
covering lifetime separation, exact session replay, typed edits, preserved base
states, rejected mixed marginal paths and invalid masks. Eight-cell controls
cover optional providers and unknown/changing context with an explicit matching
source clock. The maintained build runs the API check after learning its native
two-note source. Its exception handler now exits after exception cleanup.

Checked stable Win32/Win64 and development Win32 builds and API checks pass for
the unpreferred source and saved-preference reblend with zero reported leaks.
Changed owned files add no compiler warnings. Final Win64 preferred and hard-lock
renders preserve prior WAV/JSON bytes, and the independent-pitch render passes
actual WFC PCM/MIDI plus output checks. The unsupported joint model retains its
named scope diagnostic, exit 1, no published WAV and zero reported leaks on all
three targets. Audio was rendered on Win64 only in this checkpoint.

Initial fixture failures exposed two test setup errors: using initial generation
after a session had accepted results, and changing a context clock without
matching source-clock evidence. The fixture now uses selective regeneration and
consistent explicit timing; neither production admission rule was relaxed.
The final capture failure check found that writing a managed function result
before validation could clear the caller's previous result. Capture now stages a
local candidate and publishes only after every check; regression checks preserve
the prior result for rejected tokens, latent paths and joint combinations.
Evidence and retained before-source are under ignored `build/grid-api/`.

WFC-LAYERS no longer schedules grid API extraction; semantic role descriptors,
controls and admitted recorded-provider integration remain. The 22 broader open
outcomes and roughly 55% overall estimate remain; this completes a reusable
mechanism, not recorded musical admission. Package refresh includes the new adapter.
The primary musical bottleneck remains register/boundary admission; no held-out
recording, listening verdict or genre acceptance changed.
Documentation validation resolves 1639 local links across 61 documents with zero
errors. Final builds, API checks and render processes are terminal; source and
evidence hashes are retained in the checkpoint ledger. Branch/index are unchanged.

## Previous checkpoint — milestone alignment review, 2026-09-20

The [north-star reassessment](MILESTONES.md#north-star-assessment) remains
**100/80/30/70/25/50%** across NS-1 through NS-6: **55.5 weighted points, roughly
55%**. The retired 89.8% estimate understated the full intended musical/corpus
scope. Current source, supported contracts, study evidence and retained consumer
logs do not justify a new outcome-level increase. No multi-recording genre model
has an accepted quality verdict.

The active plan now makes the user-outcome mapping and remaining allocation
explicit: 22 unfinished outcomes, owned 0/1/10/3/6/2 by the six goals. Musical
inference and corpus quality account for 32.5 of 44.5 remaining points. Completed
capabilities stay in goal credit and topic evidence; the repeated accomplishment
list and long diagnostic narrative are removed from the milestone page.

WFC-LAYERS explicitly owns the missing reusable saved grid-pass API: assembly,
projections, typed controls, detached capture and an independent caller. Source
inspection confirms these grid responsibilities remain in the voice demo while
the duration API is already reusable. This is a clarified part of the existing
outcome, not an extra scored milestone. The style architecture no longer calls
implemented soft preferences planned work.

The next five outcome milestones retain 20.75 conditional points. Fundamentals
listening is the first quality decision; recorded register/boundary admission is
the primary implementation bottleneck. Corpus splits, modular API extraction and
delivery preparation are ready alternatives for one agent. Partial capability
credit now requires an explicit delivered-scope rationale; test/experiment counts
do not move the percentage. Historical entries below retain their original
assessments; MILESTONES.md alone owns the current backlog.

This review changes documentation only. No compiler, inference, listening or
held-out evaluation was rerun; retained evidence was inspected rather than
presented as fresh execution. The native documentation checker resolves **1623
local links across 60 documents with zero errors**. The six-goal ownership map,
44.5-point remainder and 20.75-point next-package arithmetic reconcile; reviewed
milestone/style documentation contains no private source-acquisition details.

## Previous checkpoint — saved grid-preference consumer, 2026-09-20

The [saved grid-preference consumer](WAVE-STYLE.md#grid-preference-consumer-checkpoint--2026-09-20)
now has positive generation and bounded-failure evidence. The earlier request
fails without preferences too: the source's joint pitch/rhythm model cannot
supply 64 cells. The native voice operator now identifies an individually
unsatisfiable provider after solve failure, using the actual companion path
analysis. It exits after exception cleanup rather than halting inside the handler.
The same rejected request exits 1, emits no WAV and leaves zero reported leaks
on checked stable Win32/Win64 and development Win32.

A regenerated current-format native WAV fixture supports the unchanged grid
scope. Four saved grid-provider preferences survive two blends and reach the
actual coupled passes. Win64 preferred audio differs from baseline and replays
exactly in WAV/JSON; every provider model text remains exact, as do independent
key/tempo states. A cell-0 MIDI-62 hard lock overrides the soft preference while
preserving observed joint relationships. All renders have 64 cells, 705600 stereo
frames and 120 notes; actual WFC PCM/MIDI verification passes.

Each context pass now reports its ordered preference list. The existing saved
style output fixture verifies that boundary, and its preference-control mode
checks preserved training models/base context and changed audio. Both affected
programs rebuild on all three targets; output/isolation checks pass against the
Win64 renders. Stable Win64 additionally passes hard-lock/selective checks.
Changed owned files add no warnings; existing WFC/RTL warnings remain. All final
processes are terminal with zero reported leaks. No full redundant suite or new
cross-target audio-render claim is added.

Evidence is ignored under `build/grid-preference-consumer/`. An old cached pitch
archive failed current-format decoding; it was regenerated from the maintained
WAV/context/onset inputs, without a compatibility reader. WAV-04-INTEGRATION no
longer schedules the resolved grid scope/preference/failure gap. Recorded semantic
providers, listening quality and current delivery remain open. The full goal
stays active at about 55%; this scoped consumer completion does not admit a genre.

## Previous checkpoint — native estimator execution fidelity, 2026-09-20

The optional native pitch estimator now passes a
[declared-model execution comparison](PHRASE-EVALUATION.md#native-model-fidelity-checkpoint).
A Pascal harness reads the pinned topology/named weight manifest and executes
reference TensorFlow C API operators independently of native convolution and
folded normalization. The official 2.18.1 CPU runtime and its complete notices
remain isolated under ignored build output; no production dependency is added.

Twelve controls and all 2997 cached frames from each development recording pass
the predeclared 0.0002 absolute activation / 0.5-cent decoded-frequency limits.
Recorded maximum differences are 7.152557e-7 activation and below 0.000066 cents,
with no winning-bin changes. Source/model/cache hashes, exact centers and every
input RMS are checked. This accounts for 2,162,160 compared sigmoid values,
including controls, and uses no reference labels or held-out material.

This closes the scoped numerical execution uncertainty for the pinned study
model on those inputs. Its sustained octave errors require musical interpretation;
they are not explained by a native layer/layout transcription defect in this
comparison. Calibration, provenance closure for adoption and practical native
cost remain under WAV-VALIDATION; recorded/independent phrase admission is still
open. The reference runtime's speed is not native-library performance evidence.

Checked stable Win64 controls and both full comparisons terminate successfully,
with zero Pascal heap-tracker leaks and no final build warnings. The tracker
does not cover external runtime allocations. An initial compile-only failure
used an unsupported numeric cast; it was corrected with explicit Double locals
before any comparison ran. `build/crepe-fidelity/` retains the policy, Pascal
harness, runtime/licenses, reports/logs and hashes. The environment search was
stopped after no existing reference runtime was found; all comparison processes
are terminal. No maintained algorithm, model weights, inference gate, format,
listening acceptance or completion percentage changes; the broad goal remains active.

## Previous checkpoint — companion annotation audit, 2026-09-20

The [companion annotation audit](PHRASE-EVALUATION.md#companion-annotation-checkpoint)
checks whether frame/note reference differences explain the persistent recorded
pitch failures. It uses the existing Spring development recordings and their
companion F0s labels from the same pinned preparation. No held-out recording,
inference policy or acceptance target changes.

Frame annotations support the intended upper note at 126 of 127 flute octave
errors; the remaining frame is unvoiced. All 87 wrong flute centers whose full
annotation windows lie inside a single note support the note reference. Thus
note-edge alignment cannot explain the main register failure. Violin's 22 wrong
centers split 9 supporting the note label, 8 supporting inference, 4 another pitch
and 1 unvoiced. Four remain inside full-note windows, three supporting the note
label and one inference. These related annotation products are not independent
ground truth, and neither replaces the existing note-event scoring contract.

The native diagnostic binds source/frame-file pairs, notes, score, inference and
policy; it recomputes every note label and reconciles aggregate score counts.
All 2997 centers per part match a frame annotation within the declared 5 ms.
Final checked stable Win64 runs terminate with zero reported leaks and no build
warnings. Source, policy, companion annotations, final reports/logs and hashes
remain ignored under `build/phrase-reference-audit/` (`flute-bound`, `violin-bound`).
The final interior split excludes any window overlapping a different note;
earlier unqualified reports are retained separately.

WAV-VALIDATION now has concrete frame/note disagreement evidence. WAV-03-REGISTER
still needs musical identity evidence capable of resolving sustained subharmonics;
another boundary-trimming or global octave rule is unsupported. WAV-03-BOUNDARIES
retains its separate uncertainty/ending work. Maintained inference and source
formats are unchanged; the broad goal remains active at about 55%, with no new
completion credit for diagnosis.

## Previous checkpoint — reconciled milestone backlog, 2026-09-20

The [north-star reassessment](MILESTONES.md#north-star-assessment) now reconciles
the full project scope with **22 unfinished outcomes**, owned 0/1/10/3/6/2 by
NS-1 through NS-6. Goal estimates remain 100/80/30/70/25/50%, or **55.5 weighted
points, roughly 55%**. The former 89.8% denominator is retired. Existing mechanisms
are credited; reliable musical inference and corpus quality still own 32.5 of
44.5 remaining points. No multi-recording genre model has an accepted verdict.

The review found saved preferences already implemented beyond the previous work
record. Inspected source, retained three-target fixture logs and current WAV hashes
support [persistence/reload/reblend and duration replay](WAVE-STYLE.md#saved-generation-preferences).
The completed WFC-PREFERENCES mechanism is removed from the active list; its
stable anchor points to NS-4 credit. Remaining semantic mapping is in WFC-LAYERS.
The failed coupled-grid attempt is explicitly owned by WAV-04-INTEGRATION,
including baseline/scope diagnosis and failure cleanup. Its failure is not
attributed to preferences without a baseline comparison.

CORPUS-SCALE now explicitly owns reconciling many-recording growth/repeated reuse
with ancestry, source and model bounds. Delivery names the later saved/runtime
preference changes missing from packages. Related topic pages no longer schedule
implemented persistence. The five next outcome milestones retain **20.75 potential
points**, conditional on their acceptance; no credit is awarded for this review.
The first implementation package targets discriminating register evidence and
independent admission, with corpus setup and bounded consumer checks ready while
their downstream musical verdicts remain blocked.

This checkpoint changes documentation only. Existing source, study reports,
fixture logs and audio hashes were inspected; compilation, inference, listening
and held-out evaluation were not rerun. Historical entries below are evidence,
not competing active backlogs. MILESTONES.md owns current sequencing and scope.
Local validation resolves **1615 links across 60 documents with zero errors**.
The 22-row goal ownership map and 20.75-point next-package arithmetic reconcile.
Review logs and document hashes are retained under ignored
`build/milestone-alignment-current/`.

## Previous checkpoint — runtime generation preferences, 2026-09-20

Runtime [generation preferences](LAYERS.md#generation-preferences) now extend the
owned WFC layer adapter. Positive token multipliers influence actual WFC choice
weights without rewriting learned counts or weakening constraints. Named sessions
detach settings, include pending preference edits in selective dependency closure,
retain them across model replacement and restore original graph weights after
every solve. Invalid requests and failed solves preserve accepted results.

The existing layer fixture passes checked stable Win32/Win64 and development
Win32 with zero reported leaks. On each target, both ordinary and fixed-partition
graphs select the favored token 237 rather than 120 times in the fixed 256-choice
panel. Independent key tokens/states remain exact and dependent articulation stays
valid. Replay, neutral scaling, ownership, hard-lock precedence, failed-solve
recovery, replacement, clearing and preparation/weight bounds pass. Existing
WFC/RTL compiler warnings remain; changed owned code adds none.

The native layer demo accepts `OUTPUT.wav [SEED [LAYER TOKEN MULTIPLIER]]` and
records settings in its current report beside unchanged model texts. Stable
Win64 default audio retains its historical hash. Seed 731 with `pairs 48:64 16`
produces a different 64-note render whose WAV and JSON replay exactly. This is an
exercised native listening path, not an operator listening verdict. API version 4
identifies the additive behavior; no historical artifact reader is introduced.

Evidence is ignored under `build/layer-preferences/`. WFC-PREFERENCES now owns
semantic mapping and current saved-style persistence through blend/reblend; its
runtime controls are credited under NS-4 rather than rescheduled. Delivery must
rebuild consumers of the extended layer record and refresh source packages.
The overall goal remains active at about 55%; recorded admission and accepted
many-recording style outcomes remain open. This turn changes maintained adapter,
fixture and demo code, with corresponding contract/backlog documentation.
Seven other direct tool/fixture callers rebuild on stable Win64. Context-profile
and saved WAV-style regressions pass with zero reported leaks. Documentation
validation resolves 1610 local links across 60 pages without errors. The checkpoint
ledger binds maintained changes, compiler/test logs and demo artifacts.

## Previous checkpoint — residual event audit, 2026-09-20

The [residual event audit](PHRASE-EVALUATION.md#residual-event-checkpoint) completes
the next diagnostic decision under WAV-03-REGISTER/BOUNDARIES. Seventeen flute
events without a correct center contain 130 of its 134 wrong-pitch centers;
127 wrong centers are lower-octave errors. Raw salience favors the reference over
the selected pitch on only three wrong flute centers and one wrong violin center.
The error is not limited to event edges: flute has 88 wrong sustain centers.

Retaining sustain states alone produces coverage/precision of 70.57%/92.41% for
flute and 75.77%/99.58% for violin. Both miss coverage, rejecting blanket edge
removal as a solution. False-rest centers are more often nearer following onsets
than preceding endings (64/18 flute, 23/9 violin); those descriptive distances
cannot authorize cuts. The next register change must discriminate wrong event
identities while retaining genuine short/quiet notes; rest-boundary evidence and
conditional model-fidelity admission remain separate owners.

The native diagnostic binds original source/reference, inferred state/interval,
score, raw metadata/salience and policy identities and reconciles every aggregate
with the existing scorer. Both final checked stable Win64 runs terminate with no
reported leaks; the build has no warnings. Evidence and reproduction instructions
are under ignored `build/phrase-residual-events/` and the linked checkpoint. The
earlier wrong-input invocation is retained separately, not counted as a passing
run. No maintained algorithm, threshold, learned model, held-out result or listening
acceptance changes. The full goal remains active at about 55%; the audit changes
the next action without earning separate outcome credit.
Documentation validation resolves 1605 local links across 60 pages with zero
errors. The checkpoint ledger binds the diagnostic source, executable, policy,
reports, successful terminal logs and updated records.

## Previous checkpoint — full milestone reassessment, 2026-09-20

The [fresh milestone reassessment](MILESTONES.md#north-star-assessment) aligns the
full intended scope with 23 unfinished outcomes. The six goal estimates remain
100/80/30/70/25/50%, or about 55% weighted engineering completion. The rationale
now explains both the credit and missing acceptance for each percentage; the old
89.8% denominator remains retired. Musical inference and corpus-style quality
account for 32.5 of the 44.5 remaining points. This is a planning judgment, not a
measured readiness or adoption score.

Completed extraction, synthesis contracts, pass timing/replacement, saved reblends,
journals and the boundary-context query stay consolidated under goal credit.
Register/boundary backlog rows now reflect the latest joint-event findings rather
than proposing work already performed. WAV-VALIDATION explicitly owns shared
uncertainty/evaluation requirements and conditional estimator parity/cost evidence;
it neither mandates a learned model nor duplicates provider accuracy credit.
Phrase admission and corpus scaling link to that requirement. The ordered next
five outcome milestones offer 20.75 provisional points, earned on acceptance.

This checkpoint changes documentation only. Existing numerical reports and native
query evidence were inspected; inference, held-out evaluation, listening and
compiler suites were not rerun. Before/after documents and local link validation
are retained under ignored `build/milestone-refresh/`. The next implementation
decision is an event-level audit of the remaining precision errors before another
inference change; corpus/protocol and semantic-contract preparation can proceed
without claiming the blocked musical outcomes.
Local validation resolves 1602 links across 60 documents with zero errors. The
23-row ownership map, goal weights and 20.75-point next-package allocation
reconcile; the revised milestone page contains no private acquisition details.

## Previous checkpoint — qualified boundary-context API, 2026-09-20

The [pitch-qualified articulation comparison](PHRASE-EVALUATION.md#qualified-event-cues-checkpoint)
replaces generic valley permission in the experimental joint decoder with the
existing pitch-context qualifier. It reduces unmatched contiguous same-pitch
reattacks from 29 to two in flute and from 15 to two in violin. Both development
recordings now pass coverage and onset/full-note F1 gates. Precision remains
89.14%/97.61%, below 98%, so full phrase admission and held-out evaluation remain
blocked. No thresholds, state costs, neural measurements or release rule change.

Flute coverage/onset/full-note F1 is 85.69%/0.8283/0.8182; violin is
88.28%/0.9385/0.8380. Qualified cues are 28/253 and 50/233. Source/reference-bound
paired audits reconcile every changed frame; no previously correct center becomes
wrong in either part. The independent event diagnostic finds one late flute ending
and seven early/two late violin endings among nearest matching pitch/onset cases.
Residual register and false-rest errors remain the next acceptance blockers.

The reusable query is extracted into the existing portable pitch-region unit as
`SummarizePitchBoundary`, with `DefaultPitchBoundaryOptions` and explicit context,
gap and region-admission controls. It returns detached side evidence, missing
context and central unresolved counts. Its qualification is a cue, not a claim
of physical attack/release or calibrated confidence. Region option validation is
shared internally; existing region semantics and learning defaults are preserved.
No dependency or saved format is added.

The expanded maintained pitch fixture passes checked stable Win32/Win64 and
development Win32. Coverage includes ownership, half-open sides/inclusive central
endpoints, zero gap, incomplete edges, caller policy and failure preservation.
Waveform controls reject smooth amplitude modulation and retain interrupted
same-note/pitch-change cues. A stable Win64 phrase-tool rebuild succeeds. Recorded
consumers compare all 486 query decisions against the original helper and replay
every report field except elapsed time, including states and inferred intervals.
All final native checks are terminal with no compiler warnings or reported leaks.

Evidence is ignored under `build/phrase-qualified-events/` and
`build/pitch-boundary-api/`; commands and scope are in the linked study and pitch
contract. The complete event policy remains experimental. Package refresh now
includes the new core query; Linux/remote CI, model parity, held-out admission and
listening acceptance are unclaimed. The goal remains active at about 55%; this
completes a reusable measurement mechanism, not the larger WAV admission outcome.
Documentation validation resolves 1590 local links across 60 pages with zero
errors. Checkpoint hashes bind the changed unit/fixture, policies, study helpers,
recorded reports, replay evidence and terminal logs.

## Previous checkpoint — joint note-event inference, 2026-09-20

The [joint note-event study](PHRASE-EVALUATION.md#joint-note-event-checkpoint)
tests attack/sustain/release inference over the cached learned salience. It improves
coverage over raw frame admission but fails the unchanged recorded gates. Flute
coverage/precision is 85.65%/87.42%, onset/full-note F1 0.7210/0.6180. Violin is
87.92%/97.00%, with F1 0.8718/0.7179. The event policy is not adopted; goal estimates
remain about 55% overall and the larger objective stays active.

An initial control caught a genuine 30-ms octave note being absorbed by an
invented same-note release/attack reset. Before recorded scoring, direct same-note
reattack was made conditional on waveform evidence and the unsupported melodic
distance prior was removed. The corrected controls preserve short/sustained octave
changes, a confused attack, repeated articulation, quiet notes and rest gaps;
replay, tuning rejection, silence and resource rejection also pass. The original
failed policy/source/trace remain available. No recorded threshold was tuned.

The 271-state decoder considers fewer than 20 million predecessor edges and runs
in 219/203 ms on the two cached 30-second excerpts; this excludes the unchanged
upstream measurement cost. Inference verifies source/model/policy/salience bindings
and independently recomputes energy. Separate reference scoring retains exact
frame centers, note tolerances and edge rules. Paired audits reconcile changes
against the baseline; the same 75 baseline flute errors remain wrong.

Independent event eligibility diagnostics find 29/31 contiguous same-pitch flute
reattacks and 15/19 violin reattacks lack a matching reference onset. Twelve flute
and fifteen violin estimates with a matching pitch/onset end too early. This
changes the boundary decision: generic waveform valleys cannot directly authorize
articulation, and release must retain genuine quiet sustain. Register evidence
remains a separate unmet prerequisite. The full recorded policy fails, so no
held-out recording, saved-style admission or listening verdict follows.

Final checked stable Win64 builds have no warnings; all corrected controls,
inference, scoring and diagnostic processes terminate with zero reported leaks.
Evidence is ignored under `build/phrase-joint-events/`, with commands and numerical
limits in the linked study. The initial control failure is retained separately.
No maintained implementation, dependency, default or format changes. The milestones
link the articulation/release gap and retained short-note counterexample to the
existing WAV-03 boundary/register owners; fundamentals listening remains open.
Documentation validation resolves 1584 local links across 60 pages with zero
errors. The checkpoint hash ledger binds the final policies, study code, inferred
events, score/audit reports and documentation; private source descriptions remain
generic WAV references.

## Previous checkpoint — native learned-pitch feasibility, 2026-09-20

The [native learned-pitch study](PHRASE-EVALUATION.md#learned-pitch-feasibility-checkpoint)
establishes bounded Pascal inference of the pinned official CREPE tiny model,
but rejects its fixed frame-admission policy on both existing development parts.
Flute coverage/precision is 80.91%/86.65%, with 173 wrong centers including 160
octave errors; violin is 72.01%/97.35%, with 32 wrong centers including seven
octave errors. No production model, default, dependency, format or musical
acceptance changes. The six goal estimates remain at about 55% overall.

All 360 pitch activations are retained for each of 2997 exact baseline timestamps
per original 16-kHz recording. Measurement never reads labels. Independent native
scoring checks source/model/policy/salience hashes, geometry, score ranges and
input RMS; paired audits reconcile baseline changes and frame totals. Compared
with the final baseline, flute fixes seven wrong centers but loses 149 correct
ones; violin fixes two and loses 385 correct centers to unknown. Most errors are
near reference boundaries, but forty flute wrong centers lie outside 50 ms of a
boundary. This localization does not exclude any center or infer boundaries.

Convolution geometry, sine/phase, normalization and input-shape controls pass.
Weak/missing-fundamental diagnostics distinguish 220-Hz evidence from genuine
440-Hz tones; very quiet normalized signals retain high activation, so the separate
energy gate remains necessary. These checks do not establish upstream numerical
parity, calibrated confidence or complete analytic note-event protection.

Two concurrent checked stable Win64 runs take 506812/505515 ms for 30 seconds
each, roughly 17 processing seconds per audio second. Each conservative bound is
110266583040 multiply-add pairs within the declared 120000000000 limit. Final
native builds have no warnings; all controls, measurement, scoring and audit
processes terminate successfully with zero reported leaks. Evidence and complete
upstream MIT notices remain ignored under `build/phrase-learned-pitch/`; no
external inference runtime is introduced. Reproduction commands are in the linked
study. No threshold sweep, held-out evaluation or listening verdict is claimed.
Documentation validation resolves 1582 local links across 60 pages with zero
errors; `checkpoint-hashes.xml` binds the final study assets, reports and records.

WAV-03-REGISTER/PHRASES still require joint note-event admission. The cached
salience can support the next declared attack/sustain/ending hypothesis without
rerunning the model, but upstream numerical fidelity and practical corpus cost
also gate adoption. Fundamentals listening remains open; the overall goal is
active. The preceding milestone reassessment remains authoritative.

## Previous checkpoint — milestone alignment review, 2026-09-20

The [north-star milestone review](MILESTONES.md#north-star-assessment) consolidates
the current plan around six goal estimates and 22 unfinished outcomes. Rechecking
the supported fundamentals, phrase/tempo results, layer/style contracts, corpus
studies and delivery evidence supports 100/80/30/70/25/50%: 55.5 weighted points,
reported as about 55%. The retired 89.8% allocation does not describe the complete
WAV/style objective. No implementation or musical acceptance is added by this
documentation review.

Completed extraction, contract review, synthesis mechanisms, fixed pass timing,
replacement, journals and saved reblends remain consolidated as goal credit.
Each open row now carries its owner, closing evidence and named downstream links.
WFC-PREFERENCES makes the architecture's outstanding output-preference contract
explicit: training-source weights and hard locks do not establish controllable
generation bias. It coordinates with semantic layer descriptors and feeds saved
styles/integration. Corpus setup explicitly covers duplicate/split integrity,
input exclusions and annotation uncertainty; independent delivery includes the
source/asset requirements for use outside this checkout.

The five next outcomes retain 20.75 provisional points: accepted fundamentals,
reliable recorded notes/context, semantic layer integration, first many-recording
style evaluation and independent delivery. Musical inference and corpus-style
acceptance own 32.5 of the remaining 44.5 points. Core listening remains ready;
register/boundary failures still block phrase freeze. Corpus/evaluation definition,
semantic contracts and target preparation can proceed without claiming those
blocked outcomes. Repeated failed local-estimator probes call for a changed
inference hypothesis, not further task-count credit.

Before/after documentation and validation evidence are kept under ignored
`build/milestone-alignment-review/`. This is a documentation-only reassessment;
numerical suites, listening, model studies and held-out evaluations are not rerun.
The goal weights, remaining allocation, 22-row ownership map and next-package
arithmetic reconcile. Local link/anchor and privacy checks pass; the architecture
now links its outstanding preference contract directly to the backlog owner.

## Previous checkpoint — normalized correlation comparison, 2026-09-20

An [independent normalized-correlation comparison](PHRASE-EVALUATION.md#normalized-correlation-checkpoint)
changes the WAV-03-REGISTER decision: the tested acoustic-estimator replacement
and simple agreement with the baseline are rejected. The native study follows
published positive-lobe peak selection with fixed, predeclared 0.93 relative and
0.8 clarity choices. It preserves the source preparation, temporal decoder,
event tuning, qualified cuts and four acceptance targets. All twelve existing
analytic protections pass; the two recorded development cases fail.

Flute qualified-cut coverage/precision becomes 86.08%/90.73%, versus
84.82%/93.90%; onset F1 falls below 0.80. Violin becomes 76.97%/97.12%, versus
80.21%/98.38%, and full-note F1 falls to 0.6020. Only 12 of 95 baseline flute
errors become correct, while 76 retain the same wrong note. Thirty previously
correct centers become wrong. Violin loses 165 correct centers, mostly to unknown.
An agreement-only frame diagnostic still fails flute precision and violin coverage.
No new estimator or agreement gate is adopted.

Independent native audits verify source/reference identities, unchanged fields
outside the candidate study, candidate-score totals, event tuning, frame scores
and note-match eligibility. Checked stable Win64 builds have no warnings; all
controls, measurements and audits are terminal with zero reported leaks. Each
recording's direct correlation-term bound is 130405464 / 268435456. No held-out
recording is used. The ignored `build/phrase-nsdf/` directory holds the declared
policy, sources, reports, diagnostic WAVs, terminal logs and checkpoint hashes.

Builds use `-B -Sa -Cr -Co -Ci -gl -gh -Fusrc -Futools`, study-local units and
separate `-FU`/`-FE` output under `win64/`. The measurement reuses unchanged
boundary helpers from `build/phrase-centered-candidates/`. Source/reference runs
use the two existing Spring development parts with `PREFIX 0 30`; independent
`audit`, `paired` and `note.changes` commands are documented with the result.

WAV-03-REGISTER now calls for an explicit joint note-event hypothesis before
another local-estimator substitution. Retain competing attack/sustain register
evidence and genuine quiet/short lower notes; scalar scores or cross-estimator
agreement do not establish admission. The larger goal remains active at about
55%, with core listening and all musical acceptance gates unchanged. No maintained
implementation, default, dependency, saved format or accepted style changes.

## Previous checkpoint — fixed timing partitions, 2026-09-20

The maintained [fixed-partition layer path](LAYERS.md#fixed-time-partitions) is
now validated through the existing named-session API. Owned contiguous tick
boundaries support unequal provider and consumer intervals alongside uniform
grids. Position/state compilation preserves original weights, histories and
extent restrictions while installing actual WFC mapped requirements during
solving. No dependency source, core ownership or saved format changes.

The expanded existing layer fixture passes checked stable Win32/Win64 and
development Win32, all with zero reported leaks. It checks nested boundary
ownership, conjunctive relationships, key-only edits, independent-state/audio
preservation, compatible replacement, contradiction recovery, replay, half-open
endpoints, wrapped seams and signed Int32 extremes. Forty order-three requests
agree with the original adapter's feasibility across all five extents and 1..8
cells. Value/matrix/requirement preflight failures preserve accepted results and
pending edits. Fixed timing does not infer durations selected within a solve.

All twelve fixture WAVs match across the three targets; the eight existing files
retain their preceding uniform-grid hashes. Four new two-second, 16-kHz stereo
auditions follow the unequal timing plan: the dependent voice changes after a
key edit and the independent rhythm stem stays identical. Listening remains
unassessed. These are authored controls, not new WAV-derived musical admission.

Stable Win64 also passes the saved-style fixture and recorded held-context public
performance checks. The latter uses its specified `window-bassoon-reblend.pys`
fixture; an initial invocation with a different reblend correctly rejected an
unobserved joint lock and is not a valid performance regression input. The terminal
correct-input run has zero reported leaks. Existing RTL/companion compiler warnings
remain; there are no authored-source warnings in the layer builds.

Evidence is ignored under `build/layer-partitions/{stable,trunk,win64,consumer}/`.
Layer builds use `-B -Sa -Cr -Co -Ci -gl -gh -Fusrc -Fuadapters/wfc
-Fuvendor/wfc/src` with separate `-FU`/`-FE`, then run
`pythian.tests.wfc.layers` with that target's output directory. The consumer adds
`-Futools`, runs `pythian.tests.wave.style` with a local output prefix, then
`performance-api build/recorded-pitch-3.2.2-i386-win32/window-bassoon-reblend.pys`.
`audio-hashes.xml` records target and preceding-output comparisons.
The documentation check resolves 1559 local links across 60 pages with zero errors;
current source, fixture, documentation and terminal-log hashes are retained in
`checkpoint-hashes.xml`.

The finite partition prerequisite is removed from active WFC-LAYERS work and
credited in NS-4. Semantic provider contracts, recorded integration, changing
duration planning and delivery refresh remain open; the six goal estimates and
21-outcome count stay unchanged. This completes a verified mechanism, not the
larger M3 outcome. Fundamentals listening and upstream note/context admission
remain the next acceptance priorities; the full goal remains active at about 55%.

## Previous checkpoint — milestone alignment refresh, 2026-09-20

The [milestone reassessment](MILESTONES.md#north-star-assessment) now explicitly
separates accepted results, working mechanisms and unvalidated implementation.
The six north stars remain 100/80/30/70/25/50%, yielding 55.5 weighted points
(about 55%). The former 89.8% allocation does not represent the full intended
scope. All 21 open outcomes retain a primary goal, acceptance criteria and named
dependencies. NS-3 musical inference and NS-5 corpus-style quality account for
32.5 of the remaining 44.5 points, about 73% of remaining scope.

The review found maintained timing-partition code already in the working tree,
including owned boundaries and position compilation in the named-session adapter.
The existing stable Win64 layer fixture passes with zero reported leaks, but
contains no partition-specific cases. This is unfinished implementation, not an
accepted extension of the prototype evidence. WFC-LAYERS now explicitly owns its
ownership, geometry, selective-edit/replacement recovery, limits, replay, audio,
consumer and documentation checks. No implementation was changed in this review.

Completed experiment details stay in topic evidence rather than the active rows.
Corpus-scale acceptance now explicitly links vocabulary/capacity and semantic
provider prerequisites while allowing independent workload preparation. Delivery
includes the partition work once validated. The five outcome milestones retain
their provisional 20.75-point contribution; no credit is awarded for this review.
Core listening acceptance remains open, and independent inference/corpus work
can proceed. The next checkpoint must report which acceptance decision changed,
even when the overall percentage does not.

Documentation validation and before/after snapshots are kept under ignored
`build/milestone-refresh/`. Validation checked 1554 local links across 60 documents
with zero errors. The 21-row goal mapping and 55.5/20.75-point arithmetic reconcile;
private-source descriptions remain generic. This documentation review does not
rerun numerical suites or claim new listening or musical acceptance.

## Previous checkpoint — position compilation study, 2026-09-20

A [position-qualified compilation study](LAYERS.md#position-qualified-compilation-study--2026-09-20)
now supplies a bounded public-API route for fixed unequal event timing. Each
event/state pair gets its own graph value and mapped provider query; original
state weights, structural compatibility and extent restrictions are preserved.
Captured original states pass the companion's path validator. All 15 preceding
8/16/32-event requests solve with zero pass retries, using unchanged budgets.

A key-only edit now regenerates the voice without supplied note masks. A
contradictory voice edit preserves accepted tokens/states and recovers when
cleared. Point and complete-span semantics differ correctly at a crossed key
boundary. Replay, all five extents, a one-cell cycle contradiction and unequal
raw weights pass. Free paired 16-event renders match the earlier locked-control
WAV hashes. Listening remains unassessed.

Nine requests using the existing recorded saved reblend's rhythm, pitch and
duration models agree with the original sequence adapter: four solve and five
are contradictory. The short order-three runs do not support longer prefixes;
compilation preserves this limitation and leaves their model bytes unchanged.
This checks reuse, not new musical admission or style quality.

Position expansion requires explicit capacity policy: the prototype limits
expanded values to 1024 and the two reference relation arrays plus initial-domain
array to 16 MiB, excluding other storage. At 32 positions/32 states, those arrays
use 12615680 bytes; local compilation takes 437 ms and solving 4782 ms. A
64-position/32-state request rejects before graph application. The initial
per-edge builder's large case was deliberately stopped after the eight-state
case exposed repeated inverse-closure cost; batched public rule arrays resolve
that preparation issue. Both final native processes are terminal with zero
reported leaks and only existing RTL/companion warnings.

Policy, Pascal sources, logs, hashes and auditions remain ignored under
`build/positioned-pass-study/`. Checked stable Win64 builds use
`-B -Sa -Cr -Co -Ci -gl -gh -Fusrc -Fuadapters/wfc -Fuvendor/wfc/src
-Fubuild/positioned-pass-study`, separate output directories and `-Futools` for
the recorded consumer. The runs are `study.exe build/positioned-pass-study/win64`
and `recorded.exe build/saved-trajectory-win64/reblend.pys`.

WFC-LAYERS now targets integration of this bounded compiler with owned fixed
plans, named sessions and aggregate resource accounting. General provider
intervals, changing-duration planning and larger-model cost remain open. The
demonstrated route needs no companion edit. No maintained code, format, listening
verdict or percentage changes; the full goal remains incomplete at about 55%.

## Previous checkpoint — nonuniform commit filter, 2026-09-20

A bounded [nonuniform event-time study](LAYERS.md#nonuniform-event-time-feasibility--2026-09-20)
now identifies a concrete WFC-LAYERS contract gap. Unequal note durations need
different provider sampling at each occurrence; the pinned public lattice queries
are uniform and value-scoped. An actual WFC commit hook verifies the relation but
does not filter those domains before search. Only two of 15 free requests solve
within the fixed 64 pass retries; all 16/32-event requests hit the retry limit.
The maintained uniform-grid controls solve 15/15 without retries.

The native prototype uses real learned models, explicit key/voice dependencies
and public sequence capture. A fully constrained 16-event control verifies attack
semantics, conflicting-edit rollback, key/voice regeneration scope and paired
138000-frame stereo renders at 24 kHz. Its paired edit explicitly supplies both
masks; it is not evidence of free dependent note selection. The first successful
free case reproduces tokens, latent states and the negotiation transcript.

Checked stable Win64 execution is terminal, with zero reported leaks and only
existing RTL/companion compiler warnings. Fixed policy, native source, logs,
auditions and source/artifact hashes are ignored under
`build/nonuniform-pass-study/`. The prototype was built with
`-B -Sa -Cr -Co -Ci -gl -gh -Fusrc -Fuadapters/wfc -Fuvendor/wfc/src`, separate
unit/executable output in that study's `win64/` directory, then run as
`study.exe build/nonuniform-pass-study/win64`.

The commit-filter approach is rejected for general nonuniform mapping. WFC-LAYERS
now links a scoped prerequisite: public position-specific relationships during
solving, with bounded preparation and preserved learned paths/counts. Fixed
accepted duration plans are the first consumer; changing durations within a
solve additionally needs an explicit time/planning contract. Uniform providers,
corpus preparation and inference remain independently ready. No maintained code,
dependency, format, listening verdict or completion percentage changed. The full
goal remains incomplete at about 55%; fundamentals listening is still open.

Documentation validation resolves **1715 local links across 61 documents with
zero errors**. The ignored checkpoint ledger binds the final policy, native study
sources, model/attribution identities, reports, terminal logs and updated records.

## Previous checkpoint — milestone reassessment, 2026-09-20

The [milestones](MILESTONES.md#north-star-assessment) have been reassessed against
the full project profile and the current capability, learning, style and delivery
evidence. The old 89.8% allocation remains retired. The six goal estimates remain
100/80/30/70/25/50%, or 55.5 weighted points, reported as about 55% engineering
completion. This is a fresh review of acceptance, not a new implementation or a
claim of ecosystem adoption.

All 44.5 remaining points now reconcile explicitly to the six goals and 21 open
outcomes. Completed extraction, contract review and reusable mechanisms stay in
goal credit and topic evidence. Experiment history is removed from the active
register row; its next acceptance decision and evidence link remain. Open rows
now explicitly cover semantic many-hour aggregation, provider/time normalization,
overlapping source contributions in further blends, preservation of joint evidence
and comparative style-transfer evaluation. Existing source coalescing and
normalization are credited; their extension to new providers remains open.

The dependency order keeps fundamentals first, permits independent inference,
corpus, WFC-contract and delivery preparation, and blocks only named downstream
acceptance. The next five outcome milestones provisionally contribute 20.75
points if fully accepted; they leave broader musical coverage, all-three-style
acceptance and final delivery/use visible. No completion credit is awarded for
this review. No implementation, format, generated audio or dependency changed.
Validation checked 1264 local links across the milestone/work pages and their
incoming-reference documents: 18 pages, zero errors. Documentation-only scope
does not require another synthesis or inference test run.

## Previous checkpoint — spectral register diagnostic, 2026-09-20

An independent [spectral register diagnostic](PHRASE-EVALUATION.md#spectral-register-checkpoint)
now compares each inferred event pitch with its neighboring octaves using
candidate-centered eight-period Hann windows and the native FFT. Its predeclared
first/prime harmonic peak/gap score is inspired by published work, not a full
implementation of that method. Seven stationary controls pass, including missing
and weak fundamentals, quiet/DC cases and silence rejection.

Recorded ranking is unsuitable for adoption: only three of 95 wrong flute centers
rank the intended note highest, while 97 of 1755 correct flute centers prefer a
wrong octave. Violin retains all 2006 correct and 32 wrong rankings. None of the
three improved rankings resolves a previously absent candidate. These are
diagnostic alternative rankings; existing inference, phrase scores and saved
learning remain unchanged.

The measurement checks source and prepared-excerpt identity and does not read
annotations. A separate report/reference-bound audit verifies window/event
coordinates and all three alternatives before scoring. Checked stable Win64 runs
are terminal, without compiler warnings; work is 82308670 / 107117802 within the
268435456 cap. Native sources, fixed policy, scores and audits remain ignored
under `build/phrase-spectral-register/`. No parameter sweep, held-out recording,
maintained implementation/default/format change or new milestone credit occurs.

The next register hypothesis must explain attack/continuation context and the
fully wrong-register events, while preserving genuine short lower notes and weak
fundamentals. A spectral winner, global common-octave preference or whole-event
veto is not established by this evidence. Fundamentals listening remains open;
the full goal is incomplete and the overall assessment remains about 55%.

## Previous checkpoint — octave-conflict rejection, 2026-09-20

The pending octave-conflict experiment is terminal and
[rejected](PHRASE-EVALUATION.md#candidate-likelihood-checkpoint). Its rule drops
an entire event after three locally winning competing-octave windows. Flute
precision rises from 93.90% to 95.23%, below 98%; violin coverage falls from
80.21% to 74.41%, below 80%, without removing any wrong violin center.

A new native paired audit confirms unchanged source/reference identities,
top-level measurements and all raw candidate frames. Retained events are exact;
four flute events removed 59 correct and 29 wrong centers, while two violin
events removed 145 correct and zero wrong centers. Brief competition erased
much longer correct events. The twelve analytic controls pass but none activates
this rejection, so they do not establish its recorded discrimination.

The likelihood audit additionally finds the reference candidate stronger at
only 11 of 95 wrong flute centers, weaker/equal at 43 and absent at 41. Raw
candidate support remains distinct from musical correctness. Checked stable
Win64 reports, audits, policies and native sources are ignored under
`build/phrase-candidate-likelihood/`; the original process was resumed to its
terminal result, not restarted. No maintained inference/default/format change
or held-out evaluation occurred.

WAV-03-REGISTER now targets attack/continuation-local ambiguity rather than
whole-event rejection or another global phase/coherence cutoff. Fully correct
events erased by this policy are retained as counterexamples. The 21-outcome
backlog and about-55% assessment remain unchanged; fundamentals listening and
the full musical goal remain incomplete.

## Previous checkpoint — fundamental contract review, 2026-09-20

[FUND-CONTRACTS is complete](FUNDAMENTALS.md#contract-review) for the previously
declared native suite. The final review maps all ten capability families to
their consumer, ownership/failure and workload evidence, retaining the existing
explicit support decisions. It does not add codecs, host-device guarantees,
atomic filesystem publication or automatic musical inference by implication.

The current core was compared by raw content with the verified trajectory
snapshot: 79 units are unchanged; only declared-phase fitting and synthesis work
accounting differ. Their later three-target/consumer results were inspected,
alongside the terminal full-build and combined-workload evidence. Current source
hashes, the changed-file list and reviewed log hashes are ignored under
`build/fundamental-contract-review/`. No implementation changed and no redundant
build suite was rerun for this review.

The completed item is removed from the active milestone list and credited in
NS-2, with the old anchor retained there. There are now 21 open outcomes.
NS-2 remains 80% and overall progress about 55% until the larger M1 quality
outcome is accepted; no fractional credit is awarded for this review alone.
FUND-QUALITY still needs the combined listening verdict and any demonstrated
fixes. The ready M2 register/boundary and pulse/context work remains available
while listening observations are outstanding; held-out recordings stay unused
until the inference policy is frozen. Delivery refresh remains separately open.

## Previous checkpoint — automation work accounting, 2026-09-20

The fundamentals workload review found a missing work charge for all five voice
automation controls. `SynthFrameCost` now charges 16 times each curve's depth,
following the existing gate-envelope convention, in addition to source/envelope
work. Offline, scheduler and tone-stream consumers share the corrected cost.
The [admission regression](SCHEDULING.md#automation-work-admission--2026-09-20)
failed before the correction and now verifies rejected replacement preserves
pending audio, exact-bound admission and rejection before source construction.

Checked stable/development Win32 and stable Win64 pass scheduler, control-curve
and modulation fixtures. Stable Win64 additionally passes source, instrument,
music-instrument and actual-WFC saved-style fixtures. The 40-note combined workload
is rerun on all three targets: all twelve WAVs retain the original hash and sample
measurements, while the initial reservation correctly rises from 10632 to 11656.
All completed fixture/workload runs report zero unfreed blocks. Source, regression
and terminal logs are bound under ignored `build/automation-work/`.

The [fundamentals map](FUNDAMENTALS.md) records this resolved accounting gap.
No processing, saved format, dependency or index change is involved. Existing
source packages predate the correction and remain assigned to delivery refresh.
FUND-CONTRACTS still needs the remaining supported-workload review; FUND-QUALITY
still needs listening acceptance. Overall engineering progress remains about 55%.

## Previous checkpoint — milestone alignment, 2026-09-20

The [milestone reassessment](MILESTONES.md#north-star-assessment) now gives the
reason for each north-star percentage and a complete index of 22 open outcomes:
two fundamentals, nine WAV inference, three WFC composition, six corpus/style
and two delivery outcomes. Extraction is complete and has no active task.
Completed implementation remains consolidated in goal-level credit and linked
evidence. The old 89.8% allocation stays retired; the current full-scope judgment
is about 55%, with adoption separately unmeasured.

The next package retains five accepted outcomes worth approximately 21 overall
points, with explicit dependencies and a concrete first-work sequence:
fundamentals verdict first, reliable note/context admission next, early corpus
split preparation, declared semantic-provider integration and affected delivery.
Roughly 24 points would remain after that package; broader musical coverage,
all three intended styles and final independent use remain on the backlog.
This is a planning/documentation review, with no new implementation or musical
acceptance claimed. Current source contracts and recorded topic evidence were
reviewed; no experiments or full build suites were rerun for this assessment.

## Previous checkpoint — even-harmonic phase, 2026-09-20

The [even-harmonic waveform phase probe](PHRASE-EVALUATION.md#even-harmonic-phase-checkpoint)
now uses a second/fourth-harmonic-only fit to refine candidate phase before
measuring odd coherence. Seven new controls pass, including detuning, vibrato,
quiet scaling, missing reference rejection, real octave change and amplitude ramp.
Earlier integration/harmonic controls still pass.

The unchanged source-bound Spring development events have 47 measurable flute /
65 violin cases under the fixed second-harmonic availability guard. Odd coherence
improves in 15/47 flute and 51/65 violin cases; residual improves in 24/47 and
53/65. Fifty-two flute / twenty violin events lack reference support. Original
geometry exclusions remain. Correct/error coherence still overlaps, including
wrong flute event 58 at 0.8113 versus correct event 77 at 0.7181. These are
conditional diagnostic results, not a note-admission policy or accuracy gain.

The independent identity-bound audit retains all event labels/boundaries and
previous pitch counts, including 84 downward-octave flute errors. Checked stable
Win64 measurement/audit runs are terminal and have no compiler warnings. Native
sources, predeclared policy, knots, reports and hashes remain ignored under
`build/phrase-even-phase/`; conservative work is 60652800 / 73249920, below
268435456. No held-out input, scalar threshold selection, maintained-code change,
new format, vendor edit or branch/index change occurred.

The next register action changes direction: investigate acoustic candidate
likelihood and temporal/attack support rather than another unconditional
coherence cutoff. Conditional phase modeling remains useful evidence for
WAV-03-TIMBRE, but a general phase provider is not a prerequisite for all register
work. Fundamental listening remains open; overall engineering progress stays
about 55%, and the full goal remains incomplete.

Documentation validation resolves 378 local links across the three changed pages
with zero errors. The backlog now links the conditional phase result and the
separate next register investigation.

## Previous checkpoint — candidate-frequency phase, 2026-09-20

The [candidate-frequency phase probe](PHRASE-EVALUATION.md#changing-phase-checkpoint)
now uses per-window exact-note frequency knots, linear interpolation and
sample-wise trapezoidal integration to supply the new core harmonic fitter.
The policy preserves the preceding probe's event labels/boundaries and windows;
missing support or invalid phase geometry remains unmeasured. Constant/glide
integration, rejected-support controls and the eight harmonic controls pass.

On the source-bound Spring development excerpts, estimated phase lowers fit
error in 91/99 measurable flute events and 66/85 violin events. Correct and
wrong-register coherence still overlap: wrong flute event 58 reaches 0.8890,
correct flute event 79 is 0.2626, and correct violin event 18 is 0.0216. The
separate identity-bound annotation audit confirms unchanged pitch counts,
including 84 downward-octave flute errors. Two violin events additionally fail
the four-cycle requirement in unchanged windows and remain unmeasured.

All measurement/audit runs are terminal on checked stable Win64, with no compiler
warnings. Native sources, exact phase knots, policies, source/report bindings,
JSON and logs are ignored under `build/phrase-changing-phase/`. Conservative
paired-fit work is 30326400 / 36624960, within 268435456. No held-out input,
threshold selection, note edits, maintained-code change or new format is involved.

WAV-03-REGISTER and WAV-03-TIMBRE retain the phase-uncertainty/shape/support gap.
Next admission work must distinguish these effects using paired evidence; a lower
residual cannot authorize pitch doubling or rejection. Fundamental listening
remains open, and the overall engineering judgment remains about 55%.

The native documentation checker resolves 398 local links across four affected
pages with zero errors. The unchanged candidate reports and the new diagnostic
sources/results are fingerprinted in the ignored evidence ledger.

## Previous checkpoint — combined fundamentals, 2026-09-20

The [combined fundamentals workload](SYNTHESIS-QUALITY.md#combined-workload-checkpoint)
now joins four source families, independently controlled modulation, a two-tempo
40-note score, shared biquad/ADSR rendering, six buses and a reverb tail. A direct
public-playing-voice timeline supplies the placement reference. Scheduled output
at 1/257/4096-frame reads matches every Single sample; all twelve WAVs across
checked stable/development Win32 and stable Win64 are byte-identical.

The predeclared 11-second/24-kHz scope passes initial silence, exact timing,
headroom and tail criteria. Peak is 0.212615907 without gain repair, RMS is
0.031678146 and all voices/reserved work are released. Heap tracing reports zero
leaks; all three builds have no warnings. The existing native converter/meter
also verifies unity-gain 44.1/48-kHz outputs, exact duration and byte-identical
257/4096-frame replay on stable Win64. All runs are terminal. Source, policy,
hashes, logs and auditions remain under ignored `build/combined-fundamentals/`.

This supplies connected consumer evidence for FUND-CONTRACTS/FUND-QUALITY; it
does not replace an independent DSP reference or establish automatic style
quality. The audition is available for listening, but no listener verdict has
been recorded. No maintained code, format, vendor, branch or index changed;
inventory remains 81 core / 24 adapters / 63 fixtures. Overall assessment remains
about 55%, and the full goal is still incomplete.

Next work retains the combined listening/coverage gate and responds to concrete
audible or workload defects; corpus/context/phrase admission can proceed under
its named dependencies. The latest packages still predate recent core/adapter
changes. This study does not refresh their evidence.

The existing native documentation checker resolves 398 local links across the
four affected pages with zero errors. The active backlog links the completed
combined check without treating it as another task to repeat.

## Previous checkpoint — phase fitter and fundamental contracts, 2026-09-20

The [declared-phase harmonic fitter](SOURCES.md#phase-harmonic-fitting) now has a
documented public contract and affected-consumer verification. It fits constant
coefficients along caller-supplied changing phase, retains sampled frequency
bounds and residual evidence, and rejects invalid geometry/work/rank. Phase-path
inference, automatic register selection and changing-phase saved evidence remain
separate acceptance work; no format or inference default changed.

The existing three-target source checks report zero leaks; all six WAV outputs
match across stable/development Win32 and stable Win64. A new checked stable-Win64
saved-style run passes stationary/trajectory fitting, saved envelopes, independent
instrument controls and second derivations. The recorded trajectory reblend still
renders five notes / 19845 frames with actual WFC verification and unchanged WAV
hash `29c8d382d02fdba4928c313f8345389ffcd5d21daa22525846c7885d6ba34d75`.
Both consumer runs report zero leaks. Logs and the cross-target hash ledger are
under `build/phase-harmonic-consumers/`; the checked flags include
`-B -Sa -Cr -Co -Ci -gl -gh`. All runs are terminal.

The new [fundamental capability map](FUNDAMENTALS.md) connects ten core capability
families to contracts, consumers and boundary fixtures. It makes unsupported
WAV/I/O, instrument-policy and host-runtime cases explicit, rather than treating
unit counts as complete coverage. FUND-CONTRACTS now owns the remaining combined
consumer/workload review; public phase API consolidation is removed from its
open work. Combined listening still belongs to FUND-QUALITY. The overall
engineering judgment remains about 55%, with no increment for these supporting
checks. Source packages still predate the recent core/adapter changes.

No implementation, format, vendor, branch or index changes were made in this
verification/documentation pass. Next work is the combined fundamental review
and any concrete defect it exposes; recorded phase/register admission retains
its separate dependency chain.

Documentation validation resolves 672 local links across eight affected pages
with zero errors. Neither affected consumer build reports owned-unit warnings;
existing compiler-generics and companion warnings remain scoped to those sources.

## Previous checkpoint — final milestone alignment, 2026-09-20

The [north-star assessment](MILESTONES.md#north-star-assessment) remains about 55%
against the full intended outcome, replacing the old 89.8% allocation. The final
alignment audit preserves six goal owners, explicit completion boundaries and
an open-only dependency-linked backlog. Completed mechanisms stay in the goal
summaries and topic evidence. The next five accepted outcomes contribute about
21 provisional percentage points; individual experiments do not earn automatic
increments.

The audit adds FUND-CONTRACTS to make fundamental capability, ownership and
failure/recovery coverage explicit alongside FUND-QUALITY's combined listening
review. It also assigns changing-phase measurement/admission gaps to
WAV-03-TIMBRE and corrects delivery wording: the verified snapshots predate
recent layer replacement, mapped grids/dependency correction and the core phase
fitter. Affected delivery verification belongs to WAV-05-DELIVERY.

The phase fitter already exists in the working tree. Its source-fixture logs
under `build/phase-harmonic-{stable,trunk,win64}/` report passing constant/glide/
vibrato/quiet controls and zero leaks on all three targets. These are declared
phase controls, not inferred recorded phase, shared-consumer acceptance or
listening approval. Remaining API/evidence consolidation is linked from
FUND-CONTRACTS; no additional completion credit is assigned.

This alignment pass changes documentation only and preserves current code,
fixtures, artifacts, branch and index. Core contract/quality acceptance is the
first priority; corpus protocol and register/boundary/context investigations
remain ready under their named dependencies.

Validation: the existing native documentation checker resolves 779 local links
across 12 affected/reference pages with zero errors. Goal ownership, dependency
order, package-evidence scope and provisional contribution arithmetic were
reviewed. No library suite was rerun for this documentation-only reassessment.

## Previous checkpoint — harmonic coherence, 2026-09-20

The [short-window harmonic-coherence probe](PHRASE-EVALUATION.md#harmonic-coherence-checkpoint)
tests register evidence on the existing centered, qualified-cut Spring phrase
reports. Eight analytic controls pass their stationary-identity or bounded-metric
checks. The native measurement retains 103 flute / 90 violin inferred events;
99 / 87 have sufficient window/harmonic scope. A separate reference audit confirms
unchanged frame counts, including 84 downward-octave flute errors.

The result rules out a simple coherence cutoff: an entirely wrong flute event
has coherence 0.7674 over two windows, while a correctly pitched flute event has
0.1370 over its first sixteen windows and a correct violin event has 0.0776.
Stationary true weak fundamentals retain coherence 1, but vibrato, ramps and a real
octave transition reduce it. These counterexamples require event/attack context,
frequency-drift treatment and explicit support length before harmonic evidence can
become an admission policy. No threshold sweep or pitch edit was selected.

Policy, native measurement/audit sources, controls, JSON and logs are ignored under
`build/phrase-harmonic-coherence/`. Checked stable Win64 runs are terminal; source,
excerpt, candidate and reference bindings agree. Fit work is 15163200 / 18312480,
below the declared 268435456 bound. Maintained code, defaults and existing scores
are unchanged. Held-out recordings remain unused; no listening verdict or milestone
credit is added. WAV-03-REGISTER remains open alongside boundary inference before
phrase freeze; the overall engineering judgment remains about 55%.

## Previous checkpoint — mapped layer grids, 2026-09-20

The public layer adapter now supports
[explicit musical-time mappings](LAYERS.md#explicit-musical-time-mappings) between
unequal uniform pass grids. Callers declare a common tick domain and choose
start-tick sampling or all-provider-cell coverage. Actual WFC mapped requirements
retain public-token alternatives, conjunctive providers, latent model identity
and negotiated solving. Missing bounded coverage, endpoint overflow and excessive
preparation reject before graph construction; wrapping is explicit. Session grids
are detached and survive compatible model replacement.

The new 1/4/2/8-cell key/rhythm/harmony/voice control exposed an existing dependency
error: WFC retains default predecessor edges after switching to overlay mode.
The adapter now clears those edges before adding declared projections. Editing key
therefore leaves a later independent rhythm pass outside the actual regeneration
closure. The ordinary no-grid session fixture checks that scope too. The current
`LearnedLayersVersion` is 2 to identify the corrected behavior; no file format or
historical reader was added, and vendor source is unchanged.

The extended layer fixture passes checked stable Win32/Win64 and development
Win32 with zero reported leaks. It covers mixed index/mapped providers, selective
edits and replacement, start versus full-span semantics, signed origins, partial
coverage, exclusive endpoints, wrapped periods, contradictions and work limits.
Paired native auditions change the mapped voice's pitches while the independent
rhythm stem stays byte-identical. Evidence is under
`build/layer-time-map-{stable,win64,trunk}/`. This establishes declared controls,
not automatically learned harmony/parts or listening-quality acceptance.

The existing saved-style/performance fixture passes checked stable Win64. The
original layer demo retains WAV hash `f18415eaa85dccff19f5ac192ab23636ccb9364227b838050f432c0346560eb2`.
The saved recorded trajectory reblend still generates five notes / 19845 frames
with actual WFC PCM verification and WAV hash
`29c8d382d02fdba4928c313f8345389ffcd5d21daa22525846c7885d6ba34d75`.
These are affected-consumer checks, not a replacement for final delivery evidence.

WFC-LAYERS now owns semantic provider integration/persistence and nonuniform or
cross-schema relationships; the implemented uniform mapping is removed from its
remaining work. Fundamentals listening and recorded musical admission remain open.
Overall assessment stays about 55%; a larger NS-4 acceptance result remains due.
Inventory stays 81 core / 24 adapters / 63 fixtures. Source-package snapshots
predate these adapter changes; branch/index and artifact formats are unchanged.

## Previous checkpoint — layer model replacement, 2026-09-20

The public [layer-model replacement](LAYERS.md#transactional-model-replacement)
contract now permits replacing a compatible provider or consumer inside an
accepted named session. Actual WFC resolves the affected closure, including pending
mask edits; a detached candidate solve fixes independent passes to their exact
accepted latent states. Existing masks and relations are retained. Publication is
transactional; incompatible vocabulary or contradiction leaves the original
session and caller output intact. Temporary independent domains are removed before
publication, so later selective edits remain usable. Names/scopes/relations stay
fixed; this is not cross-schema migration or streaming audio replacement.

The extended existing layer fixture passes checked stable Win32/Win64 and
development Win32 (`-B -Sa -Cr -Co -Ci -gl -gh`), with zero reported leaks. It covers
changed model order, a two-edge dependency chain, independent one-cell context,
retained nested masks, pending edits, ownership, replay, second replacement,
consumer/ancestor contradictions and failure recovery. Paired native auditions
change rhythm while preserving an independent key stem byte-for-byte. All four
WAV outputs replay identically across the three targets. The existing saved-style
fixture, including public performance sessions and independent instrument controls,
also passes checked stable Win64. Evidence: `build/layer-replacement-{stable,win64,trunk}/`.

WFC-LAYERS remains open for semantic composition and explicit cross-resolution
relationships. Overall assessment stays about 55%; this API increment does not
claim the larger NS-4 outcome. Combined fundamentals listening and recorded musical
admission remain open. Inventory stays 81 core / 24 adapters / 63 fixtures; no
format, vendor, branch or index changes. The previous source packages predate this
adapter addition; their evidence is not represented as verifying the new API.

## Previous checkpoint — north-star reassessment, 2026-09-20

The [milestones](MILESTONES.md#north-star-assessment) have been reassessed against
the full intended end state. Six north stars now own every active backlog item:
precursor extraction, fundamental synthesis, trustworthy WAV inference, granular
WFC composition, many-hour style corpora, and independent delivery/use. The old
89.8% allocation is retired. The new weighted engineering judgment is about 55%
(55.5 by arithmetic); this is a broader denominator, not a loss of working code
or a measured claim of ecosystem adoption.

Completed work is consolidated into the goal assessments and removed from the
active list. [Dated WAV studies](WAV-STUDIES.md) preserve detailed evidence and
incoming links. Newly explicit gaps include learned harmony/groove, mixed-part
ownership, semantic provider composition, corpus splits/coverage, phrase/section
structure, style/blend evaluation and independent distribution/use. Dependencies
distinguish ready investigation from blocked acceptance; the next five larger
outcomes carry about 21 provisional points on the new denominator.

The goal-level completion boundaries now state what 100% requires for each north
star. The next-package dependency audit also makes explicit that reliable notes
and context (M2) do not supply accepted mixture roles, harmony, groove or timbre
by themselves: M3 includes that upstream admission work before claiming learned
semantic blends. First-workflow credit leaves broader supported-provider coverage
open; all three intended styles remain required for the corpus goal. No additional
percentage is awarded for this planning clarification.

Before this reassessment, the experimental
[pitch-continuation probe](PHRASE-EVALUATION.md#pitch-continuation-checkpoint)
finished on checked stable Win64. Eleven controls pass. Recorded flute scores
are unchanged; violin complete matches improve 75→76 while preserving attacks,
pitches and event count. This is development evidence only: no maintained policy,
held-out admission or milestone credit. Reports and diagnostic auditions remain
ignored under `build/phrase-pitch-continuation/`; all runs are terminal.

This reassessment changes documentation and planning only. The verified library,
formats and package bytes remain as recorded below; root branch/index/history
are unchanged. Next work follows the new dependency order, prioritizing core
quality while preparing corpus acceptance and addressing register/boundary/context
failures. No completed extraction or package refresh is reintroduced as busywork.

The final dependency/acceptance review resolves 611 local links across 13 pages
including packaging (`build/milestone-reassessment/links-followup.log`); the
earlier page selection and its 762 checks remain in the original log. All 233
implementation, test, tool, example and packaging source files match the verified
delivery snapshot. Evidence and before-copies are ignored under
`build/milestone-reassessment/`; no redundant library suite was run for this edit.

## Previous checkpoint — trajectory delivery, 2026-09-19

The [source packages](PACKAGING.md#current-source-packages) now include the core
and saved spectral trajectories, centered pitch and energy-fall APIs. Fresh ZIP
extraction verifies every content hash and all 81 core / 24 adapter units.
Packaged examples and the journal workflow pass on checked stable Win32 (core)
and Win64 (WFC). Copies of the existing source/pitch/onset fixtures pass against
both extracted packages; the saved-style fixture also passes against WFC.

An external voice consumer uses only extracted library/helper sources and the
previously verified trajectory/static second blend. Its actual WFC generation
and PCM verification pass; WAV, MIDI and preview replay exactly. This closes the
affected source-package gap in [WAV-05-DELIVERY](MILESTONES.md#wav-05-delivery),
with three spans / five notes, without claiming general phrase/style acceptance.

Evidence is ignored under `build/delivery-trajectories/`. The fresh isolated
295-file snapshot fetched both pinned dependencies and passes the complete
maintained checked stable-Win32 build. Snapshot
`0dccc0b5fbb76db48236bc2bed4c76a8dfebc7d4` and final checkout status are clean;
root branch, HEAD and index remain unchanged. All runs are terminal. No
implementation, fixture count or artifact contract changes.
The ledger remains 89.8%; Linux/remote CI, combined listening and recorded
context/phrase acceptance remain open. Next provider work follows the existing
[dependency order](MILESTONES.md#execution-order-and-blocking-links), with register
and boundary investigations independently ready before phrase freeze.

## Previous checkpoint — backlog dependency order

The [backlog execution order](MILESTONES.md#execution-order-and-blocking-links)
now explicitly includes pulse → automatic context admission, register/boundaries
→ phrase admission, and accepted phrase/register evidence → automatic timbre
assignment. Integration names its timbre prerequisite in both directions.
These are scoped acceptance dependencies; independent diagnosis, declared-region
timbre work, fundamentals and package refresh remain runnable. Existing item IDs,
clearing criteria and evidence links remain the backlog contract. Documentation
only: no new implementation, package verification or percentage credit is claimed.

## Previous checkpoint — sustained-tail evidence

The [sustained-tail condition](PHRASE-EVALUATION.md#sustained-tail-checkpoint)
requires a terminal low RMS run, complete context before the next attack and
nonperiodic/silent confirmation instead of selecting the strongest energy fall.
Eight pre-recording analytic controls protect quiet continuing notes, temporary
dips and short gaps. It changes 14 flute and three violin endings while retaining
unresolved evidence; complete matches remain 81/75 and overall admission stays
open. No thresholds are tuned to the two recordings.

The four diagnosed early violin endings remain unresolved. Source-bound context
reveals matching-pitch continuation after one proposed ending, followed by
energetic but nonperiodic windows; other cases retain fluctuating unpitched energy
or insufficient quiet context. Unmeasured periodicity remains distinct from a
measured no-period result. The [backlog](MILESTONES.md#execution-order-and-blocking-links)
now separates pitch-supported event continuation from uncertain residual sound,
retaining independent attack boundaries and the register prerequisite for trusted
note identity. Both investigations still gate phrase freeze and held-out work.

Checked stable Win64 controls/probes are terminal. Evidence and diagnostic sine
auditions are ignored under `build/phrase-sustained-tail/`. No maintained code,
default, saved contract or cross-target claim changes in this turn. Held-out
sources remain unused. Inventory stays 81 core / 24 adapters / 63 fixtures,
ledger 89.8%, general style readiness unquantified. Package-refresh and listening
gates remain open; branch and index are unchanged.

## Previous checkpoint — energy-fall evidence

The native [energy-fall primitive](ONSETS.md#energy-fall-evidence) now complements
onset localization through one bounded sliding-power implementation. It retains
before/after levels, contrast, rejected measurements and clipped/search-edge
flags. Independent power-sum, stereo, tie, failure and maximum-rate checks pass
on checked stable Win32/Win64 and development Win32, alongside existing onset
and valley checks. No unit, fixture or artifact format is added.

The [release probe](PHRASE-EVALUATION.md#energy-fall-release-checkpoint) rejects
using the strongest local decline as a note ending: flute complete matches fall
81→50 and violin 75→35, with substantial coverage loss. The experiment preserves
attacks, pitches and event counts; it binds source/reference/excerpt hashes and
keeps the original thresholds. A strong decline often occurs inside an active
note. No threshold retry or production gate rule is adopted.

Evidence is ignored under `build/release-evidence-{win64,stable,trunk}/` and
`build/phrase-release-evidence/`; the recorded probe is stable Win64 only. All
processes are terminal. The [backlog](MILESTONES.md#execution-order-and-blocking-links)
now requires sustained tail/activity and following-attack evidence, with explicit
uncertainty, under WAV-03-BOUNDARIES. Register work remains independently ready;
both still gate phrase freeze and held-out evaluation. Held-out sources remain
unused. Packages predate this API and previous additions; listening gates remain
open. Inventory stays 81 core / 24 adapters / 63 fixtures, ledger 89.8%, general
style readiness unquantified. Branch and index are unchanged.

## Previous checkpoint — centered candidate and articulation comparison

The [centered candidate comparison](PHRASE-EVALUATION.md#centered-candidate-checkpoint)
applies the verified timing geometry to the existing development phrase
experiment while keeping threshold, temporal, tuning and attack policies fixed.
Flute's uncut coverage/precision rise to 85.07%/93.72%, with octave errors down
from 93 to 84; precision still fails. Violin's coverage improves, but complete
matches fall from 76 to 70 uncut and 79 to 75 with qualified cuts.

Independent native event diagnosis attributes the violin loss to four early
endings and one merged pair of repeated MIDI-72 notes. Existing attack cuts
restore the repeated pair; they do not fix those endings. The remaining flute
errors include 41 interior centers, eight without reference-candidate support.
All wrong violin centers remain near annotated boundaries. Annotations enter
evaluation/diagnosis only, never inference or threshold selection.

Twelve analytic controls and independent candidate, tuning, frame-score and
event-eligibility audits pass on checked stable Win64. Evidence and diagnostic
sine auditions are ignored under `build/phrase-centered-candidates/`; all runs
are terminal. No maintained implementation/default, artifact contract or
cross-target result changes in this turn. Held-out recordings remain unused.
The [backlog](MILESTONES.md#execution-order-and-blocking-links) now calls for
independent attack/release evidence under WAV-03-BOUNDARIES, alongside register
work; both still gate phrase policy freeze and held-out evaluation. Inventory
remains 81 core / 24 adapters / 63 fixtures, ledger 89.8%, general style readiness
unquantified. Existing package-refresh and listening gates remain open. Branch
and index are unchanged.

## Previous checkpoint — centered pitch measurement

The [centered pitch measurement](PITCH.md#centered-periodic-measurement) removes
the prefix estimator's lag-dependent timing offset for callers aligning local
pitch and spectral windows. It shares existing validation/unknown machinery,
reports a bounded work estimate and leaves default track/learner policies and
saved contracts unchanged. No dependency source, new unit or fixture is added.

Analytic center-frequency, time-reversal, stationary-harmonic, gain/DC, stereo
and boundary checks pass on checked stable Win32/Win64 and development Win32.
The six constant/chirp cases stay within 1.202411 cents of their analytic center;
the declared limit is three cents. A 27-window native probe reduces glide fit
residuals from about 0.20 to 0.06 and reduces error against the independently
authored constant spectrum. The existing saved-style fixture passes on Win64.
Evidence is ignored under `build/centered-pitch-{win64,stable,trunk}/`, with probe
source under `build/pitch-timbre-probe/`; all processes are terminal.

The probe also preserves the unresolved gates: a dominant second harmonic still
admits an octave error despite a low residual, a mixed interval crossing an octave
step remains unknown, and recorded A's third fit still exceeds 0.25 (0.250556).
No automatic changing-pitch style policy is adopted. The
[backlog](MILESTONES.md#execution-order-and-blocking-links) links automatic timbre
pitch admission to register ambiguity and event assignment to phrase admission;
declared-region quality work remains ready. Current packages predate this API
as well as trajectory work. Inventory remains 81 core / 24 adapters / 63 fixtures;
ledger 89.8%, general style readiness unquantified. Branch and index are unchanged.

## Previous checkpoint — saved spectral trajectories

The [saved trajectory provider](WAVE-STYLE.md#saved-spectral-trajectories) retains
source-bound raw fits and note-relative timing in the current style contract.
Repeated blends combine normalized harmonic shapes while envelope selection stays
independent. Stationary-only behavior remains unchanged; mixed static/trajectory
rendering explicitly normalizes both contributions. No historical format branch
or new unit/fixture is added.

Checked stable Win32/Win64 and development Win32 pass independent union-knot
references, bounds, ownership, saved further blends, actual WFC generation and
88-note instrument rendering. Paired melody timbre/envelope edits preserve other
stems, the independent binding and complete MIDI. 127/2048-frame replay is exact;
rendered WAVs match across targets. Relearned archives differ in floating-point
fit evidence; saved bytes decode canonically across Win32/Win64. Evidence is
ignored under `build/saved-trajectory-{win64,stable,trunk}/`; all runs are terminal.

The recorded C trajectory passes three windows; the A third window still fails
the declared 0.25 residual threshold (0.253358 at measured frequency). Rejection
preserves accepted output. Its previously admitted stationary spectrum supplies
the mixed-source blend; no A trajectory acceptance is claimed. The
[dependency-ordered backlog](MILESTONES.md#execution-order-and-blocking-links)
marks saved control evidence satisfied, retains changing-pitch/recorded/listening
gates, and links automatic event assignment to phrase admission. Ready work does
not wait for unrelated blockers. Packages predate these additions and need an
affected refresh. Inventory remains 81 core / 24 adapters / 63 fixtures; ledger
89.8%, general style readiness unquantified. Branch and index are unchanged.

## Previous checkpoint — magnitude shape and level separation

The [magnitude trajectory path](SOURCES.md#magnitude-trajectory-checkpoint) now
separates a fitted periodic spectrum's modeled cycle RMS from its normalized
shape. An explicit constructor corrects level throughout interpolation, while
retaining pitch-cap attenuation. Raw phase-preserving trajectories are unchanged.
The maintained WAV consumer exposes both modes and reports modeled level
separately from measured finite-window AC RMS.

Independent references verify midpoint correction, shared partials and omitted
high-frequency energy. Gain/phase-varied WAV controls recover the intended shape
within one PCM16 unit; source/stream/consumer checks pass on stable Win32/Win64
and development Win32. New auditions match across targets and the prior raw
recorded output retains its hash. Invalid targets and rendered overload preserve
accepted output. Evidence is ignored under
`build/timbre-shape-{win64,stable,trunk}/`; all processes are terminal.

[WAV-03-TIMBRE](MILESTONES.md#wav-03-timbre) now proceeds to source-bound saved
trajectory evidence, explicit timing/factorization policy and repeated blends
with independent envelope/timbre edits. This does not establish automatic event
assignment, changing-pitch admission, perceptual loudness or listening acceptance.
The current style archive has not changed in this turn; no historical-format
branch is added. Packages still predate trajectory work. Inventory stays 81 core
units / 24 adapters / 63 fixtures, ledger 89.8%, general style readiness
unquantified. Branch and index remain unchanged.

## Previous checkpoint — evolving spectral rendering

The [spectral trajectory path](SOURCES.md#spectral-trajectory-checkpoint) now
renders 2..32 independently measured spectra through one bounded native source,
with caller-controlled time progression and shared phase. The maintained source
consumer fits explicit WAV windows, rotates their local phase coordinates and
renders authored notes or existing generated MIDI. Three bassoon windows pass
their declared residual limit and drive a 45-note, 5.25-second audition.

Analytic/ownership checks, independent known-coefficient WAV reconstruction and
127/2048-frame stream replay pass on stable Win32/Win64 and development Win32.
New audition bytes match across targets; the old two-bank morph retains its hash.
The existing saved-style/instrument fixture passes on stable Win64. Invalid
consumer admissions preserve existing output. Evidence is ignored under
`build/timbre-trajectory-{win64,stable,trunk}/`; all processes are terminal.

[WAV-03-TIMBRE](MILESTONES.md#wav-03-timbre) names the remaining provider work:
separate dynamics from spectral change, retain pitch/phase uncertainty, then
persist and repeatedly blend trajectories in the current style contract. It is
independently runnable and gates the existing evolving-instrument requirement in
WAV-04-INTEGRATION. Combined listening acceptance remains open. Source packages
predate this addition and need an affected refresh; the earlier delivery result
still describes its exact snapshot. No new unit/fixture, historical format branch
or percentage credit is added: 81 core units / 24 adapters / 63 fixtures, 89.8%
ledger, general style readiness unquantified. Branch and index are unchanged.

## Previous checkpoint — register and transition diagnosis

The [register and transition diagnosis](PHRASE-EVALUATION.md#register-boundary-diagnosis)
separates the remaining phrase failures: the uncut temporal flute result has 93
downward-octave errors and 44 wrong interior centers, while all 33 wrong violin
centers lie within 50 ms of annotated note boundaries. Source-bound harmonic
fits expose some weak lower-register evidence, but a true lower note with a
dominant second harmonic defeats a simple pitch-doubling rule. Four analytic
controls and independent report audits pass on checked stable Win64; evidence
is ignored under `build/phrase-register-context/`. No inference policy is adopted.

The [backlog order](MILESTONES.md#execution-order-and-blocking-links) retains
independent register and boundary investigations, both feeding phrase development
acceptance, policy freeze and held-out evaluation. Accepted phrases and base
context then feed style integration alongside vocabulary, continuity and synthesis
quality gates; final accepted-path delivery follows integration. Each affected
item links its prerequisites, blocking result, clearing evidence and downstream
item. Held-out recordings remain unused. Inventory and the 89.8% ledger are
unchanged; general style readiness remains unquantified.

## Previous checkpoint — current source delivery

The [current source packages](PACKAGING.md#current-source-packages) now include
81 core units, optionally all 24 WFC adapters and the maintained journal operator
with its three helpers. Fresh 91/219-file ZIP extractions pass complete inventory
and byte checks; all owned library units compile and all five/seven examples run
on stable Win32/Win64 respectively. The WFC package also runs cache creation,
range learning, a saved blend and further blend, frozen-palette fit, source-context
attachment and replay using only its generated example WAV.

A [fresh local source clone](PACKAGING.md#clean-source-snapshot) of all 295 owned
files plus pinned gitlinks passes the complete maintained integration build on
checked stable Win32. Athena/WFC pins were freshly fetched from their public
remotes. The snapshot is `e4d1fe32504e9d55dd3f84deba1c1d1ff9da4952`; checkout status
stays clean, and all implementation/tool/example/package bytes match the workspace.
Evidence and archives are ignored under `build/delivery-journal/`; all processes
are terminal. The working branch remains `hello-pythian`, with its index and HEAD
unchanged. No core algorithm or new fixture is added in this delivery turn.

[WAV-05-DELIVERY](MILESTONES.md#wav-05-delivery) now has current local package and
clean-build evidence. Linux/remote CI remains unverified; no usable local Linux
runner was established, and remote execution needs these sources in published
history. Final accepted-path delivery still follows
[WAV-04-INTEGRATION](MILESTONES.md#wav-04-integration), including its provider,
coverage and listening prerequisites. Independently ready work can continue on
those gates; local delivery does not admit musical quality. Inventory remains
81 core units / 24 adapters / 63 fixtures, the ledger remains 89.8%, and the
original 10.2-point package is unchanged. General style readiness is unquantified.

## Previous checkpoint — selected WAV sections through saved blends

The maintained [range workflow](WAV-STUDIES.md#journal-range-checkpoint) now trains
and measures selected sections of a WAV journal without copying audio. Explicit
ranges retain source identity, independent sample boundaries and weights through
saved profiles, repeated blends, context attachment and replay. Two distant
sections of the existing 2h17m source train 1876 observations into 145 states.
A short-source further blend retains three ranges, 409 distinct / 2712 weighted
observations and 20 weighted samples from one recording.

Independent native re-learning verifies all observed/start/end counts and range
coordinates. Initial ranged learning and saved further-blend replay match model
or audio bytes as applicable across stable Win32/Win64 and development Win32.
Whole-journal output remains byte-identical to the prior command on stable Win64;
invalid/overlapping ranges preserve prior outputs. The range option resets at
each pair. Evidence is ignored under `build/journal-ranges/`; all processes are
terminal. No core algorithm, default, file format branch or fixture inventory
change is included, and no listening or held-out acceptance is claimed.

[WAV-04-RANGES](WAV-STUDIES.md#journal-range-checkpoint) is a satisfied input prerequisite for
vocabulary/continuity evaluation. Next declare recording splits and coverage,
weighting and capacity criteria before selecting a corpus policy. Section access
does not clear those acceptance gates; automatic section inference and corpus
throughput remain scoped open work. Independent pulse, phrase and fundamentals
work stays ready. Packaging/remote CI remains open. Inventory remains 81 core
units / 24 adapters / 63 fixtures; the ledger stays 89.8% and the original
10.2-point package is unchanged. General style readiness remains unquantified.

## Previous checkpoint — maintained vocabulary-fit diagnostic

The [maintained vocabulary-fit diagnostic](WAV-STUDIES.md#palette-fit-checkpoint)
now measures frozen saved palettes per recording in a bounded journal pass. The
current joint 16/32-token profiles reproduce prior distance/occupancy/run evidence
on 129621 observations. At the explicit exploratory distance limit of 0.25, C and
A gain coverage while B loses one covered observation despite a lower mean error.
C's longest token run grows from 173 to 306. These are development measurements,
not musical admission or held-out evidence.

[WAV-04-VOCABULARY](MILESTONES.md#wav-04-vocabulary) now names the remaining order:
declare recording splits and coverage/weight/capacity criteria, compare development
policies, freeze, then evaluate reserved recordings. It still gates corpus
admission in [WAV-04-INTEGRATION](MILESTONES.md#wav-04-integration). Dependency and
blocker links retain their clearing evidence and downstream IDs; independent
pulse, phrase and fundamentals work stays ready. The execution order distinguishes
ready investigation from blocked acceptance.

Checked journal fixtures pass on stable Win32/Win64 and development Win32; the
maintained command and three-source comparisons pass on stable Win64. Rejection
checks preserve existing outputs and input hashes remain unchanged. Evidence is
ignored under `build/palette-fit/`; all processes are terminal. No new fixture,
unit, learning default, format branch or musical acceptance is added. Packaging
and remote CI remain open. Inventory remains 81 core units / 24 adapters / 63
fixtures; the ledger remains 89.8% with the original 10.2-point package unchanged.
General style readiness remains unquantified.

## Previous checkpoint — maintained phase-family pulse fitting

The [phase-family pulse fitter](BEAT-TRACKING.md#maintained-phase-family-measurement--2026-09-19)
is now maintained code, with explicit concentration/matched-weight measurements
and a shared estimator/tracker work bound. It reproduces the prototype's three
development paths and stable-Win64 audition bytes exactly. Aligned F1 is
0.9639 / 0.8475 / 0.8974, compared with the former maintained baseline's
0.2813 / 0.8475 / 0.5714. The current report replaces circular-coherence fields;
no old fitter/reader branch is retained.

The native lab exposes a retained tradeoff: fixed-grid rank zero selects 192 BPM
instead of approximately 96 BPM on the polyphonic case, adding 19 pulses. The
96-BPM alternative survives and the local tracker matches all 20 reference beats
without extras. Rank zero is not quarter-note admission. This and the recorded
beat-level/alignment failures remain [WAV-02-PULSE](MILESTONES.md#wav-02-pulse)
constraints. Next use temporal band evidence and explicit uncertainty before
automatic WAV-02-CONTEXT, then semantic WAV-04-INTEGRATION. Independent work stays ready.

Beat, tracker and explicit-admission fixtures pass on stable Win32/Win64 and
development Win32, including seven phase/subdivision/mixture controls and work/
capacity boundaries. All three WAVs have identical onset/raw/adjusted frame
positions and observation indices across targets. One arpeggio PCM sample differs
by one quantization unit on Win32; other auditions match bytes. Stable Win64
saved-context/WFC replay verifies 23 pulse gates in 555660 frames. Core/companion
build evidence and audits are ignored under `build/beat-promotion/`; all processes
are terminal. No new held-out or listening acceptance is claimed. Current-source
packaging/remote CI remains open. Dependencies, branch and index are unchanged;
inventory remains 81 core units / 24 adapters / 63 fixtures. The full goal remains
active, the ledger stays 89.8%, and the original 10.2-point package is unchanged.
General style readiness remains unquantified.

## Previous checkpoint — optional frequency-band analysis

Optional [spectral-band analysis](ANALYSIS-WAVE.md#optional-spectral-bands--2026-09-19)
is now maintained core functionality. Caller-defined bands share the existing
FFT engine and have clip, custom-source range and bounded Int64 WAV-batch APIs.
The original feature record/journal stays unchanged. Measurements retain band
edges, magnitude and positive flux; they do not label instruments or admit tempo.

The [three-WAV probe](BEAT-TRACKING.md#frequency-band-evidence-probe--2026-09-19)
shows differing temporal accent evidence across bands. Mid-band alternation on
the abrupt-change example falls substantially after the change, while other
bands differ; acceleration supplies a counterexample to a simple winning-band
or alternation-penalty rule. Next combine temporal band evidence with explicit
metrical alternatives and sufficiency. [WAV-02-PULSE](MILESTONES.md#wav-02-pulse)
now has the measurement prerequisite, but still gates automatic WAV-02-CONTEXT
and semantic WAV-04-INTEGRATION. Independent provider/fundamentals work is ready.

Checked stable Win32/Win64 and development Win32 pass the extended existing
WAV-analysis fixture: analytic spectra/flux, stereo, resumed bands, invalid
admission and RF64 coordinates beyond 32 bits. The journal fixture passes on
stable Win64. All three WAVs have exact whole/batch band values; rebuilt maintained
beat reports and audition WAVs match the original baseline bytes exactly.
Evidence is ignored under `build/band-analysis/`; all processes are terminal.
No beat-default, format, dependency, branch or index change is included. New
listening, held-out, remote-CI and current-source packaging acceptance remain open.
Inventory remains 81 core units / 24 adapters / 63 fixtures. The goal remains
active; the engineering ledger stays 89.8% and the original 10.2-point package
is unchanged. General style readiness remains unquantified.

## Previous checkpoint — alternating-strength path experiment

The [alternating-strength experiment](BEAT-TRACKING.md#alternating-strength-path-experiment--2026-09-19)
rejects an unconditional accent penalty as a beat-level selector. Arpeggio points
and audition bytes stay exact, but abrupt-change F1 drops from 0.8475 to 0.7619
and acceleration from 0.8974 to 0.6129 at 30 ms. The policy favors slower grids
and misses true beats. Eight analytic checks pass; identical onset patterns under
slow-subdivision and fast-accent interpretations demonstrate why this evidence
cannot identify quarter-note level by itself. Insufficient pulse support must
also remain distinct from measured absence of alternation.

Next separate pulse fit, metrical interpretation and evidence sufficiency;
investigate independent band/part evidence and preserve unresolved alternatives.
Do not retune this scalar penalty against the same three development WAVs.
[WAV-02-PULSE](MILESTONES.md#wav-02-pulse) adds fast-accent/acceleration and
insufficient-evidence clearing constraints before automatic WAV-02-CONTEXT and
semantic WAV-04-INTEGRATION. Independent provider and fundamentals work is ready.

Checked stable Win64 controls, inference, fixed evaluation and native identity
audits completed. Original candidate fields, source/onset evidence, fit work and
other track settings are exact. Ignored evidence is under
`build/beat-accent-study/`; all processes are terminal. Maintained algorithms,
defaults, formats, dependencies, branch and index are unchanged. No held-out,
cross-target or listening acceptance is claimed. Inventory remains 81 core units /
24 adapters / 63 fixtures. The goal remains active; the engineering ledger stays
89.8% and its original 10.2-point package is unchanged. General style readiness
remains unquantified.

## Previous checkpoint — bounded phase families and transition comparison

The [bounded phase-family experiment](BEAT-TRACKING.md#bounded-phase-families-and-transition-comparison--2026-09-19)
improves arpeggio aligned beat F1 from 0.8675 to 0.9639 at 30 ms within the same
eight candidates. Abrupt-change and acceleration F1 remain 0.8475 and 0.8974.
Seven controls retain the declared quarter/eighth alternatives and both tempos
in a 120/90-BPM mixture. Fit-work and path-state bounds remain unchanged.

A separate 1.5-to-2 transition-ratio comparison reproduces all three candidate/
path outputs and audition bytes exactly, apart from the reported setting.
Relaxing the bound alone does not resolve the abrupt-change interpretation.
The arpeggio's raw F1 is 0.9880; onset adjustment loses one correct raw match at
30 ms. Beat-level evidence/uncertainty and alignment safeguards are the next
acceptance constraints, alongside explicit measurement semantics and bounded
resources. [WAV-02-PULSE](MILESTONES.md#wav-02-pulse) gates automatic tempo in
WAV-02-CONTEXT, then semantic WAV-04-INTEGRATION. Independent local-key, phrase,
corpus, manual-admission and fundamentals work remains ready.

Checked stable Win64 inference, seven controls and native source/onset/path audits
completed. Evidence and study sources remain ignored under
`build/beat-phase-families/` and `build/beat-phase-families-ratio2/`. All processes
are terminal. No maintained algorithm/default, dependency, format, branch or index
change is included; no new recording, held-out, listening or cross-target
acceptance is claimed. Inventory remains 81 core units / 24 adapters / 63 fixtures.
The goal remains active, the engineering ledger stays 89.8%, and its original
10.2-point package is unchanged. General musical style readiness is unquantified.

## Previous checkpoint — candidate survival and path diagnosis

The [candidate-survival diagnosis](BEAT-TRACKING.md#candidate-survival-and-path-diagnosis--2026-09-19)
now separates fitting, peak filtering, suppression, capacity and path choice.
Twelve window reconstructions reproduce all fields of the prior eight candidates
within declared numeric tolerances. A reference-compatible arpeggio phase falls
at diagnostic rank 13 in window 16; another phase family is outside the original
eight in window 17. In early abrupt-change windows, near-75-BPM alternatives
already survive, but the path chooses near 150. Its 1.5 maximum tempo ratio also
forbids a direct near-75-to-149 transition at the change.

Next implement and evaluate bounded phase-family retention separately from
beat-level/abrupt-change reasoning. Larger capacity or changed penalties alone
are not established remedies. Per-owned-window diagnostic optima use annotations
and have boundary/short-span ambiguities; they must not be stitched or reported
as inference accuracy. [WAV-02-PULSE](MILESTONES.md#wav-02-pulse) links these
remaining gates to automatic context admission and style integration. Manual
admission and independent provider, corpus and fundamentals work remain runnable.

Checked stable Win64 diagnosis completed; the original eight match even when
only the diagnostic rank walk extends to 32. No larger-candidate path was run.
Evidence is ignored under `build/beat-candidate-diagnosis/`, including source,
protocol, full positive-trial traces and logs. All processes are terminal. No
maintained algorithm/default, format, dependency, branch or index changed, and
no new recording or held-out material was evaluated. Whole-track F1 remains
0.8675 / 0.8475 / 0.8974; no new listening or cross-target result is claimed.
Inventory stays 81 core units / 24 adapters / 63 fixtures. The goal remains active,
the engineering ledger stays 89.8%, and the original 10.2-point package is
unchanged. General musical style readiness remains unquantified.

## Previous checkpoint — competing phases and bounded kernel work

The [competing-phase checkpoint](BEAT-TRACKING.md#competing-phases-and-bounded-kernel-work--2026-09-19)
raises the arpeggio's development beat F1 from 0.6265 to 0.8675 by retaining two
phases per trial tempo. Abrupt-change and acceleration results remain 0.8475 and
0.8974 at 30 ms. Six controls preserve tempo availability and the exact quarter
grid; equal/accented eighth cases retain both phases. An independent full circular
convolution checks every kernel bin/trial in the control run.

The optimized single-phase comparison reproduces the previous prototype's exact
raw/aligned points, source-observation identities and all six audition WAVs.
Conservative fit-work bounds for the two-phase condition are now 39876984 /
30271392 / 36432684 against the unchanged 64000000 ceiling. Source/onset/analysis
audits pass. This clears the measured short-clip resource pressure, not general
long-source capacity or automatic admission.

Next inspect phase loss through proposal, local-peak filtering and truncation at
the arpeggio ending; beat-level evidence still needs to resolve the abrupt change.
Do not increase candidate limits or tune transition penalties without that
diagnosis. [WAV-02-PULSE](MILESTONES.md#wav-02-pulse) retains these gates before
automatic context admission and style integration. Independent provider, corpus
and fundamentals work remains runnable. The other 22 ARTBeaT examples remain
unevaluated; future policy/criteria must freeze before held-out use.

Checked stable Win64 inference, controls and native audits completed. All processes
are terminal. Evidence and isolated study sources remain ignored under
`build/beat-phase-alternatives/` and `build/beat-phase-single/`. No maintained
algorithm/default, format, dependency, branch or index change is included; no
cross-target or listening acceptance is claimed. Inventory stays 81 core units /
24 adapters / 63 fixtures. The full goal remains active, the engineering ledger
stays 89.8%, and its original 10.2-point package is unchanged. Broader style
readiness remains unquantified.

## Previous checkpoint — subdivision and phase concentration

The [subdivision/phase experiment](BEAT-TRACKING.md#subdivision-and-phase-concentration-experiment--2026-09-19)
recovers usable pulse hypotheses lost by the single circular resultant. Six
controlled 120-BPM cases now retain that tempo alternative, versus three under
the baseline; the exact quarter-note grid is preserved. On the same three
annotated development WAVs, aligned F1 becomes 0.6265 / 0.8475 / 0.8974 at 30 ms,
versus 0.2813 / 0.8475 / 0.5714. Native audits verify unchanged source identities,
onset observations and analysis policies. No additional recordings were evaluated.

The arpeggio now follows roughly 144 BPM, but discarded competing phases leave
half-beat errors. The abrupt-change case still favors 150 BPM throughout. Next
retain multiple phases at one tempo and beat-level alternatives, with explicit
uncertainty; keep proposal measurement separate from path selection and admission.
The prototype uses almost the full fit budget on short clips, so efficient bounded
kernel work also gates adoption. These remain [WAV-02-PULSE](MILESTONES.md#wav-02-pulse)
requirements feeding context admission and style integration; independent local-key,
phrase, corpus and fundamentals work remain runnable.

The prototype is isolated under ignored `build/beat-phase-study/` and is not
selected for maintained use. Checked stable Win64 controls, inference, evaluation
and source/observation audits completed; study source, reports and auditions are
retained. No listening, cross-target or held-out acceptance is claimed. All
processes are terminal. Maintained code/defaults, formats, dependencies, branch
and index remain unchanged; inventory stays 81 core units / 24 adapters / 63
fixtures. The full goal remains active, the engineering ledger remains 89.8%,
and the original 10.2-point package remains unchanged. General style readiness
is still unquantified.

## Previous checkpoint — independent annotated beat baseline

The [independent annotated beat baseline](BEAT-TRACKING.md#independent-annotated-development-baseline--2026-09-19)
now exercises three preselected ARTBeaT development WAVs against author-supplied
timestamps. Unchanged defaults yield aligned F1 0.2813 / 0.8475 / 0.5714 at 30 ms.
Two wrong beat-level paths have zero seam warnings. Onset observations support
39/42, 25/26 and 35/40 reference beats, so absent attacks alone do not explain
the failures. The arpeggio largely lacks useful retained tempo candidates; the
abrupt-change case retains early near-75-BPM alternatives but selects near-150
throughout. The acceleration ends at approximately half the reference tempo.

Next address [WAV-02-PULSE](MILESTONES.md#wav-02-pulse): candidate retention under
subdivisions and explicit beat-level alternatives precede automatic tempo
acceptance in WAV-02-CONTEXT and semantic style integration. Local-key, phrase,
corpus and fundamentals work remain independently runnable. Freeze any selected
policy and acceptance criteria before separate-recording evaluation. No default
was changed, and the remaining 22 dataset examples were not evaluated.

Checked stable Win64 inference and native evaluation completed; an independent
ordered-matching dynamic program verifies match counts. Source/reference/report
hashes, policies, annotations, candidates and six source-plus-marker auditions
are retained under ignored `build/beat-context-study/`, with full dataset license
and attribution. No listening, key, cross-target or held-out acceptance is claimed.
Inventory remains 81 core units / 24 adapters / 63 fixtures. The engineering
ledger stays 89.8%, the original remaining package stays 10.2 points, and broader
style readiness remains unquantified. All processes are terminal; the full goal
is active. Branch, index, dependencies, maintained implementation and formats
are unchanged.

## Previous checkpoint — backlog links and streamed FM/PM quality

Backlog coordination now explicitly records prerequisites, blockers, clearing
evidence and downstream IDs in the [execution order](MILESTONES.md#execution-order-and-blocking-links).
Ready investigations remain independent; register/boundary development precedes
phrase admission, accepted providers precede style integration, and final delivery
verifies that accepted source. Context admission now names its reference-based
clearing evidence, and integration/delivery link in both directions. This is a
documentation clarification; no new experimental result or percentage credit.

The core now provides `pythian.synth.resample.TTonePcmReader`, a bounded borrowed
adapter from finite tone streams to the existing PCM resampler. The maintained
scheduler fixture verifies fractional conversion, partial blocks, suffix reads,
repeated EOF, ownership and external-read poisoning on all three Windows targets.
The [FM/PM checkpoint](MODULATION.md#streamed-fmpm-bandwidth-checkpoint--2026-09-19)
then verifies source factories through actual tone streams and bounded downsampling
against independent Bessel/filter references. The four auditions match across
targets, read sizes and cache settings; no high-rate full clip is retained.

The [consolidated quality scope](SYNTHESIS-QUALITY.md) now connects stationary
timbre, measured envelopes/layers, export headroom, sample/automation transitions
and streamed FM/PM evidence. Next review that declared coverage and its combined
auditions for concrete audible defects, while independent context, phrase and
corpus investigations remain runnable. No listener approval or general style
quality is claimed. The engineering ledger stays 89.8%; the original 10.2-point
remaining package is unchanged and does not bound the full goal's remaining work.

Inventory is 81 core units, 24 adapters and 63 fixtures; no new fixture program
or format branch was added. All processes are terminal. Evidence is ignored under
`build/fm-stream-{study,stable,trunk}/`; the native audit also creates the three-
second FM/PM comparison. Dependency pins, branch, index, current-package and
remote state are unchanged. The full goal remains active.

## Previous checkpoint — sample-loop and automation quality

The integrated sample/automation study passes 18 transition paths and a paired
bandwidth control on checked stable Win64 and stable/development Win32. Analytic
source, phase, filter, envelope and control references cover a smooth authored
stereo loop with changing pitch, cutoff, pan and gain. All 20 audition WAVs match
byte-for-byte across targets, and 127/2048-frame reads replay exactly. The
[checkpoint](SOURCES.md#sample-loop-and-automation-quality-checkpoint--2026-09-19)
records the fixed input/range limits and acceptance metrics. No maintained
renderer change was needed; all study/audit processes are terminal. Evidence is
ignored under `build/loop-modulation-{study,stable,trunk}/`.

Next connect FM/PM source-factory sideband behavior to the actual tone stream and
bounded downsampling path, then consolidate the declared synthesis-quality limits
and auditions for listening review. Discontinuous recorded loop endpoints and
arbitrary fast modulation are not covered by this smooth-loop result. The scoped
[FUND-QUALITY](MILESTONES.md#fund-quality) evidence advances without closing its
remaining acceptance or changing the 89.8% ledger / 10.2-point outcome package.
Register, boundary, context and corpus-quality investigations remain independently
runnable; the full goal remains active and general style quality unquantified.

## Previous checkpoint — measured-envelope quality and export headroom

Measured envelope/layer quality passes 81 conditions on checked stable Win64 and
stable/development Win32, with nine byte-identical auditions across targets.
Independent retained-RMS and harmonic references cover one-frame through two-
second gates, three rates, further style blends and up to 32 overlapping voices.
The [checkpoint](INSTRUMENTS.md#measured-envelope-and-layer-checkpoint--2026-09-19)
records exact scope, bounds, source identities and remaining limits.

The overload probe exposed a real operator gap: `pythian.instrument.style` exported
clipped PCM for supported polyphony. It now rejects stem or mix peaks above unity
before replacing outputs and accepts explicit `--output-gain 0..1`, preserving
role balance and profiles. Native checks on all three targets verify rejection,
all-six-output preservation, staging cleanup, gain and read-size replay. The
existing 88-note measured performance retains exactly the same mix/stem PCM on
stable Win64. Low-level codec saturation and core float headroom are unchanged.

Next address integrated sample-loop and modulation transitions plus the remaining
listening criteria in [FUND-QUALITY](MILESTONES.md#fund-quality). The scoped export
blocker is cleared; broader audible style integration retains its named provider
and quality gates. Register/phrase research remains independently runnable.
All study/check processes are terminal. Artifacts are ignored under
`build/instrument-envelope-{study,stable,trunk}/` and
`build/instrument-headroom-{study,stable,trunk}/`. The five-outcome package remains
10.2 points and the engineering ledger 89.8%; no small-increment credit is added.
General style quality remains unquantified and the full goal remains active.

## Previous checkpoint — stationary-timbre and glide quality

The measured-instrument quality study passes 264 declared conditions on checked
stable Win64 and stable/development Win32. Saved stationary timbre is exercised
through the actual instrument and streaming renderer at four rates, seven sampled
keys and three velocities, plus twelve two-octave glides. Independent additive,
phase, filter and authored-envelope references bound the error; all 24 saved
auditions are byte-identical across targets. The
[quality checkpoint](INSTRUMENTS.md#measured-instrument-quality-checkpoint--2026-09-19)
records scope, acceptance, commands and limits. No maintained renderer change
was needed. All study processes are terminal; artifacts remain ignored under
`build/instrument-quality-{study,stable,trunk}/`.

Next extend [FUND-QUALITY](MILESTONES.md#fund-quality) to measured-envelope retiming,
different note lengths and overlapping-layer headroom, retaining the existing
bounded-stream and replay evidence. Sample-loop/modulation coverage and listening
remain open. This independent core work does not wait for register research.
The [execution order](MILESTONES.md#execution-order-and-blocking-links) retains
prerequisite, blocker and coordination links: provider admission precedes style
integration, then final verification of the accepted source. Update both ends
when a named gate clears. The five-outcome package remains 10.2 points; this
scoped study earns no additional credit. The engineering ledger stays 89.8%,
and general style quality remains unquantified.

## Previous checkpoint — adjacent-note projection

The adjacent-note projection experiment is not selected for adoption. Giving each
continuous pitch two neighboring MIDI interpretations improves flute precision
slightly to 93.55% but still fails admission; violin coverage drops to 79.65%,
losing the preceding event-tuning condition's development pass. Its 33 wrong
centers remain despite reference-note support now being available at 19 of them.
More candidates alone do not resolve musical selection. The
[checkpoint](PHRASE-EVALUATION.md#candidate-note-projection-checkpoint) records
the fixed-policy comparison, twelve passing controls and independent native audits.
All study processes are terminal on checked stable Win64; evidence is under
ignored `build/phrase-note-projection/`. Maintained code/defaults and held-out
recordings remain unchanged.

Next address the independently ready [FUND-QUALITY](MILESTONES.md#fund-quality)
outcome: declare and exercise pitch/rate/velocity, bandwidth, gain and transition
quality through the existing measured-instrument path. Register research remains
linked to boundary evidence and phrase admission, with explicit event/register
context needed before further scalar tuning. Ready fundamentals work does not
wait for that research. Preserve the five-outcome package and its 10.2-point
remaining allocation; no experimental increment earns extra credit. The full
goal remains active, the engineering ledger is 89.8%, and general style quality
is unquantified.

## Previous checkpoint — event-scope candidate tuning

Candidate tuning now has a separate event-scope development experiment. Retaining
cents until a decoded event's energy-weighted mean can be checked against the same
25-cent tolerance raises temporal flute coverage to 84.49%, onset F1 to 0.8265
and full-note F1 to 0.8163; precision 93.08% still fails. Violin reaches 80.09%
coverage, 98.04% precision, 0.9029 onset F1 and 0.8686 full-note F1, meeting all
four development targets in the condition without added cuts. Adding qualified
waveform cuts helps some note matches but regresses coverage/timing elsewhere;
no new default is selected.

Twelve analytic controls pass, including rejection of steady +35-cent tuning,
retention of +/-35-cent vibrato, quiet/short real octave changes, a modulated held
note and a separated repeated-note pair. The independent audit recomputes event
tuning, candidate support, mass totals and interval scores. Of 112 wrong flute
centers, 50 lack the reference pitch in the retained candidate set; all 33 wrong
violin centers lack it. Reweighting those same candidates cannot repair every
error. Next use event/attack context to distinguish register choice from missing
support while preserving measured uncertainty and the controlled counterexamples.

The [checkpoint](PHRASE-EVALUATION.md#candidate-event-tuning-checkpoint) records
all three conditions, final hashes and limits. Checked stable Win64 runs are
terminal; evidence is under ignored `build/phrase-event-candidates/`. Raw track
evidence, maintained code/defaults, dependency pins, formats, packages and the
89.8% engineering ledger are unchanged. Held-out recordings remain unused. The
full goal remains active, with register and boundary investigations feeding the
linked phrase-admission gate; general style quality remains unquantified.

## Previous checkpoint — retained candidates and temporal decoding

The latest native study retains competing periodic candidates and compares
independent selection with temporal decoding. The final shared voiced/unvoiced
pitch model improves raw flute precision from 92.19% to 94.14%, with 89 rather
than 116 octave-error centers, while preserving eight analytic controls. Coverage
77.62% and note scores still fail admission. Violin coverage is 70.81%, below its
raw baseline and the separate qualified-boundary experiment. This remains a
development hypothesis, not an adopted estimator or a complete phrase learner.

An independent native audit reproduces interval scores and checks candidate-mass
totals. It caught and verified a fix for rounding in the prototype's unknown-mass
calculation. The final candidate set contains the annotated pitch at 1822/2069
active flute centers and 2001/2501 violin centers: availability, not achieved
accuracy. All final study/control/audit processes are terminal on checked stable
Win64; held-out recordings remain unused. Evidence and exact policy are in the
[candidate checkpoint](PHRASE-EVALUATION.md#pitch-candidate-checkpoint) and ignored
`build/phrase-candidates-study/`.

Next retain continuous pitch/tuning alternatives through event inference and
combine them with articulation evidence, comparing against both raw and qualified-
boundary conditions. [WAV-03-REGISTER](MILESTONES.md#wav-03-register) remains
coordinated with boundary investigation; phrase freeze/admission follows their
development clearing results. Maintained code/defaults, dependency pins, index,
branch `hello-pythian`, packages and percentage allocation are unchanged. The
goal remains active at the existing 89.8% engineering ledger; general musical
style quality is unquantified.

## Previous checkpoint — partition energy-cost counterexample

The latest register study rejects a region-local energy reward for phrase
partitioning. It reduces flute octave errors from 64 to 50 but still fails phrase
admission; violin coverage falls from 80.61% to 79.65%. More decisively, it erases
genuine quiet lower and upper notes in two controlled octave transitions. The
preceding count objective preserves all four controls, including uniformly quiet
notes. The [checkpoint](PHRASE-EVALUATION.md#partition-energy-checkpoint) records
the exact policy, counterexamples, per-recording metrics and reproducible commands.

Checked stable Win64 builds, both recorded runs and independent interval audits
are terminal. The energy control intentionally fails two preservation checks;
count controls pass. No maintained implementation/default changes or new acceptance
credit follow. Evidence is under ignored `build/phrase-energy-study/`; held-out
recordings remain unused. Next investigate corroborating event evidence for
competing octaves, retaining these quiet-transition counterexamples. This feeds
[WAV-03-REGISTER](MILESTONES.md#wav-03-register) alongside boundary inference;
combined-policy freeze and phrase admission remain downstream. The full goal
remains active; the engineering ledger stays 89.8% and general style quality
remains unquantified.

## Previous checkpoint — periodicity-qualified boundaries

Backlog ordering now distinguishes prerequisite, blocker and coordination links.
The [execution order](MILESTONES.md#execution-order-and-blocking-links) separates
ready register/boundary investigation from combined-policy freeze and held-out
phrase admission, followed by style integration and final delivery. Independent
context, corpus-quality, fundamentals and delivery preparation remain runnable.
Maintain links in both affected rows when a blocker clears, retaining the evidence.
This documentation clarification changes no acceptance result or percentage.

The current development experiment combines admitted pitch evidence on both sides
of a waveform valley with separate pitch-change proposals. This is progress toward
phrase learning, not a frozen admission policy. The full goal remains active and
the engineering ledger stays 89.8%, with general style quality unquantified.

With pitch changes offered as optional cuts, violin reaches 80.61% coverage,
98.87% pitch precision, 0.9112 onset F1 and 0.8639 full-note F1: all four targets
on this development part. Flute reaches 85.84% coverage and 0.7725 full-note F1,
but precision 94.52% and onset F1 0.7831 still fail. Qualifying valley cuts reduces
modulation-driven over-splitting; protecting every pitch change remains harmful
on flute. No reference pitch or timing enters the candidate/partition inference.

An independent native interval audit confirms 68 wrong active flute centers,
64 of them octave errors, plus 35 false pitches in rests. Violin has eight wrong
active centers, zero octave errors and fifteen false rest centers. A separate
annotation-selected phase diagnostic probes all 68 flute errors using nearby
periodicity quality and restricted target re-estimation. It yields one correct,
61 wrong and six unresolved targets, versus one correct raw nearest note among
those same targets. This is not an overall accuracy result and changes no output;
phase sensitivity alone does not explain the register failure.

The [checkpoint](PHRASE-EVALUATION.md#periodicity-boundary-checkpoint) records
policy, primary reference, metrics and scope. Native controls distinguish smooth
held-tone modulation, a constant-power octave change and a separated repeated
note on stable/development Win32 and stable Win64. The recorded study and error
audit ran on stable Win64 only. The held-out set remains unused. Evidence is under
ignored `build/phrase-periodicity-study/` and `build/phrase-periodicity-{stable,trunk}/`.

The backlog links [WAV-03-REGISTER](MILESTONES.md#wav-03-register) and
[WAV-03-BOUNDARIES](MILESTONES.md#wav-03-boundaries) to recorded-phrase admission.
Next infer musical register from competing event-level evidence while preserving
raw periodicity, genuine low notes, octave changes and explicit uncertainty.
The investigations can proceed together; no circular completion gate is introduced.
This turn changes documentation and ignored native study artifacts only. Inventory
remains 80 core units, 24 adapters and 63 fixtures; no vendor, index, history,
maintained default, package or remote-state change is made. All study and control
processes are terminal.

## Previous checkpoint — waveform valley evidence

The portable onset unit now supplies bounded envelope-valley measurements, and
maintained `pythian.onsets --valleys` exports their policy and source coordinates.
This adds source evidence needed by phrase segmentation while leaving note-attack
admission separate. The full goal remains active; the engineering ledger stays
89.8%, with general style quality unquantified and no additional milestone credit.

`MeasureEnvelopeValleys` uses independent channel power, complete-window centers,
local minima and peaks on both sides. It retains RMS values, peak coordinates and
relative depth. Options and point/sample-neighborhood work are checked before
allocation/reads. Returned measurements are detached. Analytic fixtures cover
stereo phase, exact values/ties, thresholds, incomplete context, ownership and
resource rejection. A modulated held tone produces four valleys; a constant-power
octave change produces none. Those controls demonstrate why the measurements
cannot by themselves admit musical attacks.

The recorded development experiment adds these proposals and protects nearby
boundaries from partition merging. Previously missing flute repeated-note
proposals fall from six to two. The protected partition removes no available
boundary near the scored reference onsets. Violin complete-note matches rise
58 to 66, precision reaches 99.18% and full-note F1 reaches 0.7500; coverage is
77.05%, still below target. Flute coverage/precision improve to 79.70%/96.38%, but
over-splitting lowers full-note F1 to 0.5888. Neither result passes every declared
target. The musical policy remains experimental and is not admitted to learning.
See the [recorded checkpoint](PHRASE-EVALUATION.md#envelope-attack-checkpoint).

Checked onset fixtures and inspection builds pass stable/development Win32 and
stable Win64 without companion paths. Recorded inspection retains exact discrete
evidence across targets, with floating differences checked within 1e-9. The
default report and optional onset cue WAV remain unchanged; rejected duplicate
options preserve accepted output. The full phrase experiment and independent
availability audit ran on stable Win64 only. Held-out recordings remain unused.
Evidence: ignored `build/envelope-valleys-{stable,trunk,win64}/` and
`build/phrase-attacks-study/`, using final `fl-core` / `vn-core` reports/auditions.

[WAV-03-BOUNDARIES](MILESTONES.md#wav-03-boundaries) now links to this implemented
measurement and its remaining attack-admission blocker. Next distinguish
articulation from modulation and combine pitch-change evidence while retaining
coverage, before freezing a segmentation policy. Phrase admission still gates
semantic style integration; independent context, vocabulary, continuity and
fundamentals work remains ready. Inventory is unchanged at 80 core units,
24 adapters and 63 fixtures. No vendor, index, history, package, Linux or remote-CI
change is claimed. All study and build processes are terminal.

## Previous checkpoint — pitch-supported partition experiment

A native development experiment now tests joint pitch support and region
partitioning against the recorded-phrase quality gate. It changes the next
segmentation action but does not earn acceptance or percentage credit. The
[partition evidence](PHRASE-EVALUATION.md#phrase-partition-checkpoint)
records all conditions and the independent proposal-availability audit.

Joining nearby onset regions reduces violin fragmentation and raises full-note
F1 from 0.6042 to 0.7089, but complete matches fall from 58 to 56 and the partition
removes boundaries near ten of thirteen consecutive same-pitch notes. Six flute
same-pitch onsets already lack an original boundary within the 50-ms tolerance;
joining cannot recover them. Proposal availability ignores pitch and matching
uniqueness and is explicitly separate from note accuracy.

Support-start gating isolates another error source: original partition starts
increase false pitches in rests to 129 flute / 40 violin centers. Clipping starts
reduces them to 20 / 15 but costs coverage. Half-window pre-roll yields coverage
76.80% / 82.85%, precision 95.32% / 97.32% and full-note F1 0.6988 / 0.7089.
Every condition still fails at least one declared target. The prototype is not
adopted into maintained library behavior, learner admission or defaults.

The final native reports retain source/reference identities, every candidate and
inferred interval, objective controls and separately named diagnostic auditions.
The existing detected/gated baselines remain unchanged. Checked stable Win64
build/run evidence is under ignored `build/phrase-partition-study/`; the held-out
recordings remain unused. This turn changes documentation and ignored study
artifacts only, and all study processes are terminal. Inventory remains 80 core
units, 24 adapters and 63 fixtures;
no vendor, index, history, package or remote state changes are made.

The ordered backlog adds [WAV-03-BOUNDARIES](MILESTONES.md#wav-03-boundaries) under
[WAV-03-PHRASES](MILESTONES.md#wav-03-phrases). Next establish source-derived
missing-attack proposals and repeated-attack preservation before freezing a
segmentation policy. This blocks phrase admission, not independent base-context,
vocabulary, continuity or fundamentals work. The full goal remains active; the
engineering ledger stays 89.8%, with general style quality unquantified.

## Previous checkpoint — explicit generation capacity

The richer-model capacity investigation now supplies a full 1024-grain maintained
audition, with its scoped prerequisite and downstream links updated in the
[ordered backlog](MILESTONES.md#execution-order-and-blocking-links). The wider
goal remains active; the engineering ledger remains 89.8%, and general musical
style quality remains unquantified. No additional percentage credit is awarded.

The adapter accepts an explicit logical state-cell budget, default 262144 and
capped at 1048576. Saved `replay --state-cells N` retains the choice in the current
report. Missing values use the default; streaming retains its previous bound.
The actual full graph, learned transitions, caller constraints and solver remain
unchanged. A 771-state model now renders all 1024 grains with an explicit 789504
budget. An independent intact-graph probe checks all 1023 transitions and exactly
matches the maintained tokens. The output is 1051648 stereo 16-kHz frames / 65.728
seconds, with peak 0.502411. Independent native checks verify source bindings,
context remapping, exact token/window counts, saved coordinates and 21 analytic
PCM probes. Win32 saved replay inherits the budget and matches Win64 WAV bytes
with reversed source arguments.

The isolated full-graph probe took 12.5 seconds with sampled peak working set
27418624 bytes; the maintained pipeline took 40.4 seconds and 68423680 bytes.
These measurements cover this model on stable Win64, not universal resource
guarantees. The cell budget is neither a memory limit nor an elapsed-time limit.
Full-length refinement lowers dense assembled mismatch 0.997338 to 0.980669,
still above the pre-context 0.909442. Musical acceptance remains open. See the
[capacity checkpoint](WAV-STUDIES.md#acoustic-generation-capacity-checkpoint).

Checked learning and stream fixtures pass stable/development Win32 and stable
Win64, including selected-budget boundaries, locks, seed replay and preserved
output on rejection. All three maintained tools compile; the other direct
option-record consumers also rebuild on stable Win64. Invalid budgets and
under-budget full-length requests reject without publishing outputs. Evidence:
ignored `build/acoustic-capacity-study/` and `build/acoustic-capacity-{stable,trunk,win64}/`.
Inventory remains 80 core units, 24 adapters and 63 fixtures. No vendor, index,
history, package, Linux or remote-CI change is claimed. All processes are terminal.

Next work remains linked by the smallest required result: vocabulary admission,
context/phrase providers and continuity quality can proceed independently.
Fundamentals quality has its own ready row; final style integration waits for
those named results, and accepted-path delivery follows integration. The measured
771-state capacity gate is satisfied; it does not clear corpus or listening gates.

## Previous checkpoint — third-source reuse and vocabulary capacity

The previous turn implemented whole-context boundary refinement. This turn adds
source B to the saved repeated-blend study, evaluates shared vocabulary coverage,
exposes existing palette-capacity control and diagnoses the larger-model
generation limit. The full goal remains active; no percentage credit is added.

B's existing headroom-preserved 30-second WAV supplies 469 native observations.
Under the shared 16-token palette it occupies 13 tokens, with mean squared
feature distance 0.167415 versus 0.052507 for a B-only palette. Joint C/A/B training
with approximately equal weighted observation mass improves B but worsens A/C.
Joint 32-token training lowers in-sample feature error for all three, while WFC
state count rises from 235 to 771. These are representation diagnostics on
development material, not genre or held-out musical accuracy.

The maintained `journals --max-tokens 1..32` now exposes the existing core
capacity; default 16 is retained. It rejects combination with `--palette-from`,
whose centers remain fixed. Changing vocabulary requires compatible relearning,
not another format version. Explicit 16 retains the earlier report/model/WAV
exactly; caps one and 32 run, invalid caps and incompatible blends reject.

In the original compatible vocabulary, B receives 44 contexts / 340 windows.
A blend and further blend retain three source ranges and 143 contexts / 1398
windows. Two 65.728-second native auditions retain exact model bytes and generated
tokens while generation weights change C/A/B contributions from 378/330/316 to
182/137/705. The final training model has 2083537 weighted observations and 3349
weighted samples from 129621 distinct observations; multiplicities do not create
independent recordings. Native independent checks pass parent remapping,
token/window/source counts, saved replay, clock and analytic rendering probes.

The richer 771-state model rejects the requested 1024-grain output because it
needs 789504 state cells, beyond the unchanged 262144 budget. The exception now
reports requested cells, the limit and model-specific capacity. The boundary is
verified: 340 grains use 262140 cells and render 351232 frames / 21.952 seconds;
341 need 262911 and reject without output. The shorter verified audition is a
diagnostic and does not complete the sustained request. See the
[three-source checkpoint](WAV-STUDIES.md#journal-third-source-checkpoint) for fit
tables, weights, hashes, output checks and limitations.

Checked maintained-tool builds and existing learning/generation fixtures pass
stable/development Win32 and stable Win64. B-only 32-token models, vocabulary
identities and WAV bytes match across all three; candidate-distance decimals in
JSON differ slightly, so full report-byte parity is not claimed. The complete
three-source studies ran on stable Win64 only. Evidence is under ignored
`build/journal-third-source-study/` and `build/journal-vocabulary-{stable,trunk,win64}/`;
all processes are terminal. Inventory remains 80 core units, 24 adapters and
63 fixtures. No dependency, history, index, package, Linux or remote-CI change
occurred, and no broad suite or listener acceptance is claimed.

The ordered backlog now links [WAV-04-VOCABULARY](MILESTONES.md#wav-04-vocabulary)
to corpus admission and [WAV-04-GENERATION](WAV-STUDIES.md#acoustic-generation-capacity-checkpoint) to
sustained richer-model output. Both retain explicit clearing results; capacity
investigation can proceed on the current 771-state model without waiting for a
final vocabulary policy. Independent context/phrase work and smaller-model
continuity remain ready. There is no external blocker. The engineering ledger
stays 89.8%; general style quality remains unquantified.

## Previous checkpoint — whole-context boundary refinement

The previous turn isolated newly assembled boundary regression. This turn adds
an optional portable refinement, exposes it through maintained saved replay,
and verifies four audible paths across three declared seeds. The full goal
remains active; boundary and musical-quality acceptance remain scoped and open.

`PlanJournalContextJoins` exchanges whole source-contiguous chunks only when
their lengths and token sequences match. Locked chunks stay fixed. Every chosen
window and its metadata retain exact multiplicities, preserving tokens, source
contributions and window diversity. Swaps must reduce total sampled mismatch
without increasing assembled-boundary mean or immediate repeats. Chunk choice
itself is unchanged; this is a bounded local refinement, not optimal assembly.

`ExtractGrainJoinProbe` now provides shared overlap/EOF extraction to candidate
and context-boundary planning. Complete sample validation, partial-EOF padding
and nonoverlapping endpoint handling remain explicit. An independent constant
oracle caught precision loss from overloaded floating clamping in the new report;
explicit Double arithmetic fixes it. The expanded existing journal fixture
also covers incompatible token sequences, exact windows/metadata, locks,
detached input, no-op cases, replay and work rejection before source reads.

Maintained `replay --context-join-passes 1..8` enables the optional stage;
zero remains the default. Probe count and forward chunk radius are independently
saved in the current profile. Final coordinates/usage describe refined output,
while context-selection diagnostics remain stage-specific. No format branch is
introduced. The public API accepts positional locks; CLI positional locks remain
unexposed.

Four maintained auditions use maximum context length eight, four starts per
anchor, four refinement passes, 64 probe frames and radius eight. Dense assembled
join mismatch improves 0.989272→0.975339 and 0.987691→0.974243 at seed 731 with
default/3:1 source weights, 0.980612→0.968849 at default seed 732 and
0.977988→0.964577 at weighted seed 733. Exact window multiplicities and diversity
stay unchanged; immediate repeats remain zero. Repeated four-window sequences
fall in these four cases, but source switches increase in two. An unrestricted
weighted diagnostic adds one repeated pattern despite improved joins. The
refined assembled costs still exceed pre-context baselines near 0.88–0.90.

All four WAVs retain 1051648 stereo 16-kHz frames / 65.728 seconds and peak
0.662842. Independent native checks pass source/model/output hashes, parent
remapping, exact tokens/window counts, saved coordinates, clock and 21 analytic
source probes per output (less than one PCM16 step). Saved default/731 replay is
byte-identical on stable Win64 and stable Win32 with reversed source arguments.
Disabling refinement reproduces the earlier WAV exactly. An invalid stage
combination rejects without output. See the
[boundary checkpoint](WAV-STUDIES.md#journal-boundary-refinement-checkpoint).

Checked journal fixtures and maintained-tool builds pass stable/development
Win32 and stable Win64. Core compilation uses no companion path. Evidence is
under ignored `build/journal-boundary-{stable,trunk,win64}/` and
`build/journal-boundary-study/`; all processes are terminal. Inventory remains
80 core units, 24 adapters and 63 fixtures. No owned compiler warnings, vendor,
index, history, full-suite, package, Linux or remote-CI changes are claimed.

[WAV-04-BOUNDARIES](MILESTONES.md#wav-04-boundaries) now supplies the tested
refinement mechanism. Next evaluate broader recordings and source-chunk choices,
with separate assembled/all-boundary costs and repetition/listening evidence.
These quality results still gate [WAV-04-CONTINUITY](MILESTONES.md#wav-04-continuity);
context/phrase provider admission remains independently ready. No external
blocker or additional percentage credit is recorded; the engineering ledger
remains 89.8%, with general style quality unquantified.

## Previous checkpoint — context reuse and assembled-boundary diagnosis

The previous turn completed saved-context integration and updated its dependency
links. This turn diagnoses the next continuity gap using the saved path, renders
two bounded-reuse auditions and records the result without changing the planner
or its defaults. The full goal remains active; this is measured progress, not
musical acceptance or additional percentage credit.

A checked native Win64 survey compares chunk lengths four/eight and per-anchor
start caps unrestricted/one/two/four/eight on the existing default and 3:1 source
weight paths. All twenty cases preserve generated tokens, exact per-token/source
counts and deterministic replay, without full-path fallback. At chunk length
eight, a four-start cap reduces repeated four-window sequences 143 to 108 and
167 to 115. Overall dense seam mismatch increases 0.398256 to 0.470944 and
0.365167 to 0.464398, respectively. This is a tradeoff, not a new preferred default.

Separating source-contiguous transitions reveals the more important failure.
Their overlap mismatch is exactly zero. Newly assembled joins average about
0.99 after context selection, worse than the pre-context baseline near 0.90.
Lower overall seam scores therefore do not establish better newly assembled
boundaries. Current join planning precedes context selection, and context ranking
does not score waveform compatibility. [WAV-04-BOUNDARIES](MILESTONES.md#wav-04-boundaries)
is now the next acoustic selection result, linked as a prerequisite for
[WAV-04-CONTINUITY](MILESTONES.md#wav-04-continuity). Independent context/phrase
admission remains ready and separately gates semantic integration.

Both four-start variants render through the maintained tool as 65.728-second
stereo 16-kHz WAVs, with zero immediate repeats and PCM peak 0.662842. Independent
native checks pass saved coordinates, parent remapping, exact token/source counts,
hashes, clock and 21 cosine-window source probes per output (within one PCM16 step).
The [reuse checkpoint](WAV-STUDIES.md#journal-context-reuse-checkpoint) records
paired metrics, output hashes and limits. No listener judgment, new recording or
held-out evaluation is claimed.

Evidence is under ignored `build/journal-context-reuse-study/`; every process is
terminal. Study execution is scoped to checked stable Win64. Public comments and
documentation now clarify that chunk length caps one choice, not the final
contiguous run, and that start caps do not cap individual-window or pattern reuse.
Production behavior, inventory, format, vendor, index and history are unchanged.
No broad suite, refreshed package, Linux or remote-CI run was needed or claimed.
The existing engineering ledger remains 89.8%; general style quality remains
unquantified. There is no external blocker.

## Previous checkpoint — saved contexts, further blends and maintained replay

Saved source contexts now survive the maintained attachment, compatible blend,
further blend and replay workflow. This closes the mechanical
[WAV-04-CONTEXT-SAVE](WAV-STUDIES.md#journal-context-save-checkpoint) prerequisite. The
[ordered backlog](MILESTONES.md#execution-order-and-blocking-links) moves it into
satisfied prerequisites and updates downstream links; continuity quality and
semantic provider admission retain their separate clearing results.

Portable restoration validates and owns bounded context windows. The current
companion profile has one optional context capability, with no new format version.
Blending remaps sources and coalesces compatible anchors without multiplying
context storage by training weights. The maintained `contexts` command verifies
exact cache identities and attaches contexts without changing model bytes.
Replay exposes run-length/reuse controls and needs only the saved profile/model
and matching WAVs. Final coordinates and source-use reports reflect context
selection; join metrics still describe its preceding fallback stage. Positional
locks remain available through the core API and fixture, not CLI flags.

The real workflow attaches contexts to two compatible profiles, blends them and
blends that result again. The final profile retains 99 contexts / 1058 windows
across two source ranges. Its 1024-token audition contains 1051648 stereo frames
at 16 kHz (65.728 seconds). Saved replay is byte-identical on stable Win64 and
stable Win32, including reversed WAV argument order and inherited controls.
A generation-weight change from default to 3:1 moves source contributions from
579/445 to 802/222 grains while keeping model bytes and generated tokens exact.
Each context plan preserves its baseline's per-token/source counts.

Independent native verification checks parent coverage/remapping, saved-plan
replay, final coordinates, source/output hashes, clock and 21 cosine-window
source probes against each published PCM16 output (error below one PCM16 step).
Default dense seam mismatch falls 0.893449 to 0.398256; the weighted case falls
0.898192 to 0.365167. Final immediate repeats are zero. Repeated four-window
sequences improve 157 to 143 by default but worsen 134 to 167 with weights 3:1.
These measurements do not establish musical phrasing or listening acceptance.
See the [saved-context checkpoint](WAV-STUDIES.md#journal-context-save-checkpoint)
for hashes, scope and comparison metrics.

Checked profile fixtures and maintained-tool builds pass on stable/development
Win32 and stable Win64, including malformed data, ownership, partial EOF, core
locks, source remapping, further blends and conflicting anchors. Wrong cache
order rejects without publishing outputs. The portable context unit compiles
without companion paths. Evidence is under ignored
`build/journal-context-save-{stable,trunk,win64}/` and
`build/journal-context-save-study/`; all processes are terminal. Development
Win32 sustained audio replay was not run. Inventory remains 80 core units,
24 adapters and 63 fixtures. No owned compiler warnings were reported; upstream
diagnostics remain. No vendor, index, history, package, full-suite, Linux or
remote-CI change occurred.

Next, evaluate paired repetition and listening across recordings through the
saved path under [WAV-04-CONTINUITY](MILESTONES.md#wav-04-continuity). Independent
[WAV-02-CONTEXT](MILESTONES.md#wav-02-context) and
[WAV-03-PHRASES](MILESTONES.md#wav-03-phrases) remain ready; semantic integration
waits for their named admission results. Current delivery remains separately
open. No completion credit is added; the engineering ledger stays 89.8%, with no
defensible percentage for general style-learning quality. The full goal remains
active with no external blocker.

## Previous checkpoint — bounded source contexts and sustained auditions

The preceding goal turn completed native filtering-scale verification and
diagnosed lost source context. This turn implements the core part of
[WAV-04-CONTINUATION](MILESTONES.md#wav-04-continuation), with sustained native
auditions and explicit saved-profile integration still required.

New portable `pythian.learning.context` owns detached source bindings, copied
fallback coordinates and bounded forward contexts around measured representatives.
Construction reads journals once and stops at declared recording boundaries.
Variable-length selection preserves every generated token, exact per-token/source
counts and locked source windows. Options control maximum run length, context-start
reuse and seed. Rendering shares the existing Hann overlap-add clock and budgets.

Real-source testing exposed quota exhaustion for rare tokens with one retained
window in a source. The repeat guard initially returned the baseline in all three
cases; same-source substitutions alone could not repair the exhausted quotas.
A targeted diagnostic identified the repeated token/source coordinates. Bounded
equal-token swaps now repair those neighborhoods without changing source counts
or locks. If repair cannot meet the original repeat ceiling, the API returns the
entire original selection and reports that fallback.

The final study retains 99 contexts / 786 windows and reuses the existing
1024-token second-blend paths. At seeds 731/732/733, dense seam mismatch falls
0.889085/0.869493/0.846271 to 0.394495/0.384003/0.343304. Unique windows rise from
93/96/94 to 363/378/351, with 617/631/673 source-contiguous links and no immediate
repeats. All token/source counts, locks and deterministic replay remain exact.
The work bound is 16830464 within the unchanged 64-million budget. Longest
source-contiguous runs are eight grains / 0.704 seconds.

The repetition tradeoff remains: repeated four-window sequences rise in two
cases (127 to 144 and 142 to 197), while falling from 191 to 176 in the other.
The three stereo 16-kHz outputs retain 1051648 frames / 65.728 seconds with peaks
below 0.663. Independent cosine-window overlap-add probes agree within 6.59e-9.
This is measured acoustic continuity evidence, not musical or listening acceptance.
See [the paired checkpoint](WAV-STUDIES.md#journal-context-selection-checkpoint)
for hashes and precise scope.

The extended existing journal fixture passes checked stable/development Win32
and stable Win64: actual retained observations, storage/recording boundaries,
counts, locks, disabled sources, replay, small single-window quota repair,
disabled-context PCM parity, EOF padding and budget rejection. Core-only
compilation uses no companion paths. The sustained study itself ran on stable
Win64; cross-target sustained audio parity is not claimed.

Evidence is under ignored `build/journal-context-core-{stable,trunk,win64}/`,
`build/journal-context-audition/` (final logs/audio have `-final` suffix) and
`build/journal-context-diagnose/`. All processes are terminal. Inventory is now
80 core units, 24 adapters and 63 fixtures. Owned code has no compiler warnings;
existing upstream diagnostics remain. No vendor, index, history, format version,
package, full ordinary build, Linux or remote-CI change occurred.

Next, [WAV-04-CONTEXT-SAVE](WAV-STUDIES.md#journal-context-save-checkpoint) must persist contexts
inside the current profile, expose replay through the maintained CLI and preserve
them through compatible blends and a further blend. The core API alone does not
complete reusable-context integration. Continuity/diversity/listening and semantic
context/part providers keep their linked acceptance gates. The full goal remains
active with no external blocker or additional completion credit.

## Previous checkpoint — native filtering scale and source-context diagnosis

The preceding turn updated the dependency-ordered backlog and verified exact
rational-phase caching. This turn closes the scoped full-source native filtering
gate and diagnoses the next acoustic-context representation task. Both the
existing conversion and queued independent verifier have terminal exit zero.

Native 48000-to-16000 conversion of a 3162491094-byte floating-point stereo WAV
produces exactly 131770456 PCM16 frames (8235.653500 seconds). The checked stable
Win64 run takes 1360.673 seconds locally, including hashing and publication, with
sampled peak working set 8249344 bytes. It retains 411 history frames, 411 cached
Double coefficients and 4096-frame reads. Filtered peak 1.461604967 exceeds input
peak 1.170678139; fixed gain 0.25 yields decoded PCM peak 0.365386963.

The independent native verifier checks the entire output with irregular blocks,
exact EOF and report/output hash agreement. Eleven offline reference probes match
PCM exactly, including read boundaries, source positions beyond 2 GiB and true
EOF. Full-source evidence is scoped to this source/rate on stable Win64; the
cached/uncached, fallback, signal and failure fixtures previously passed checked
stable/development Win32 and stable Win64. See the
[filtering checkpoint](WAV-STUDIES.md#native-rate-scale-checkpoint) and
[conversion contract](DSP.md#continuous-conversion). Existing prepared inputs,
journals and learned profiles are unchanged; new PCM needs its own source binding.

A separate native probe streams the existing hash-bound feature journals to
compare source-context availability with the saved second blend's retained pool.
The pool retains 99 of 129152 distinct observations. Across three generated
1024-token paths, all 1023 token pairs occur in the journals, but only 4/5/10
remain as adjacent pool candidates. Four-token support is 981/969/970 of 1021
positions in the journals and zero in the pool. Eight-token support is
454/523/502 of 1017; 32-token support is only 0/0/2 of 993.

An independent exhaustive substring oracle checks all six investigated lengths,
source boundaries and retained-window gaps. Cache hashes and retained candidate
token/coordinate bindings pass. These are availability upper bounds, without
contribution quotas, locks, reuse limits or waveform/perceptual evaluation. The
[context checkpoint](WAV-STUDIES.md#journal-context-checkpoint) now links the evidence
to [WAV-04-CONTINUATION](MILESTONES.md#wav-04-continuation): retain bounded context
at explicit variable lengths with fallback, preserving controls, source lineage,
reload and repeated-blend behavior in the current contract. Short context is lost
by representative selection; longer matches also become scarce in the source.
Increasing bins alone cannot establish sustained musical phrasing.

The backlog moves [WAV-01-SCALE](WAV-STUDIES.md#native-rate-scale-checkpoint) to satisfied scoped
prerequisites and updates its parent and downstream links. Context/phrase provider
work remains independently runnable. Final integration still requires those
providers and acoustic continuity; current delivery remains open.

Evidence: ignored `build/native-rate-{stable,trunk,win64}/`,
`build/native-rate-scale/` and `build/journal-context-study/`. All processes are
terminal. Inventory remains 79 core units, 24 adapters and 63 fixtures. This turn
changes documentation and adds a native scratch diagnostic only; owned runtime
code is unchanged. No dependency, index, history, format version, package, full
ordinary build, Linux or remote-CI change occurred. Owned code has no compiler
warnings; existing upstream diagnostics remain. The goal stays active with no
external blocker or additional completion credit.

## Previous checkpoint — duration scope and monophonic gates

The preceding goal turn verified sustained acoustic planning and documented its
continuation gap. This turn resolves the separate mechanical duration-scope gate
and a rendering defect revealed by the longer request. Exact companion analysis
shows that the isolated-note style has only a three-span prefix: no path reaches
zero-based position 3 from position 2. Its 32-span rejection is correct; key/tempo
remain feasible. No solver budget, model transition or source repetition was added.

`TStylePerformance.AnalyzeProvider` now exposes structural feasibility for the
definition's provider scope and supplied complete token mask. It uses actual WFC
domain analysis with explicit state-cell and work bounds, without mutating a
session. The voice operator distinguishes named structural failure from solver
or pass backtrack limits. Existing performance fixtures cover independent held
context scope, performance scope and a structurally infeasible typed lock.

Development multi-note WAVs build diagnostic duration styles, a blend and a
further blend. Context deliberately retains unknown key and declares 120 BPM;
phrase-quality admission still fails. The second blend's 482-state duration model
contains 728 weighted observations from two sources. Actual three-pass generation
and public capture support 32 spans with a 4762-tick endpoint. The accompaniment
demo separately requires known key; the monophonic duration consumer accepts unknown.

PCM verification exposed previous-note release spill into adjacent pitched spans:
span 4 expected MIDI 76 but measured the prior MIDI 64. Monophonic pitch-span
auditions now terminate synthesis at each gate, using existing 44-frame interior
fades. General polyphonic release behavior is unchanged. The verifier limits its
window to each span and derives its low-frequency limit from available duration,
independently of the expected pitch. The original leaking WAV still fails.

Final checked stable/development Win32 and stable Win64 pass public API checks,
actual model/state-path validation, all 18 generated pitch measurements, silence
gates and timing. All three produce the same 218754-frame WAV. A duration-only
edit passes all 17 pitch measurements and preserves key/tempo states. The earlier
three-span audition remains byte-identical. Structural rejection is identical
across targets. See the [scope checkpoint](WAV-STUDIES.md#duration-scope-checkpoint)
for hashes and precise claims. Evidence is in ignored
`build/duration-scope-{stable,trunk,win64}/` and `build/duration-scope-study/`.

Inventory remains 79 core units, 24 adapters and 63 fixtures. Owned builds have
no warnings; upstream warnings remain. All processes are terminal. No dependency,
index, history, format, package, full ordinary build, Linux or remote-CI change
occurred. The goal remains active without an external blocker or additional
completion credit. [WAV-03-DURATION](WAV-STUDIES.md#duration-scope-checkpoint) now supplies the
supported/infeasible-request evidence; recorded phrase accuracy and part ownership
still gate musical admission. Acoustic continuation, annotated base context,
native filtering scale and current delivery remain independent open work.

## Previous checkpoint — sustained acoustic planning

The preceding goal turn implemented and verified saved acoustic blends. This turn
tests sustained passages and addresses an observed join-search scaling failure.
The saved second blend generates 1024 grains (65.728 seconds), but the original
global four-pass join search rejects the conservative work bound. Core
`TJournalJoinOptions.SwapRadius` now exposes explicit local swap proposals;
zero retains global behavior. Preflight counts all same-token pairs in the radius
to remain safe as source assignments change. `ProbeWorkBound` is reported, and
the CLI saves/reloads the policy through optional current-report fields.

Checked stable/development Win32 and stable Win64 fixtures exercise 1024-grain
local plans, sparse locks, exact token/source counts, repeat ceilings and replay;
the global over-budget case still rejects. The affected tools compile with no
owned warnings. Radius-four probes at seeds 731/732/733 reduce dense overlap
mismatch to 0.889085/0.869493/0.846271 from 0.978187/0.980038/0.987228, using planned
bounds of 19.4–21.2 million probe samples within the unchanged 64-million budget.
Independent native disk-model replay and source-coordinate rendering verify all
six paired auditions; token/source contribution counts remain exact.

The [sustained checkpoint](WAV-STUDIES.md#journal-sustained-checkpoint) also exposes
the quality gap: only 93–96 unique windows supply 1024 grains, effective window
diversity decreases, and source-contiguous runs last at most 0.32 seconds. Zero
immediate repeats and lower seam mismatch do not establish sustained phrasing.
One saved local-policy replay is byte-identical between Win32 and Win64; the
previous short global audition also remains byte-identical. No listening or
recording-level held-out acceptance is claimed.

Evidence is in ignored `build/journal-local-{stable,trunk,win64}/` and
`build/journal-sustained-study/`. Inventory remains 79 core units, 24 adapters and
63 fixture programs. All processes are terminal. No vendor/index/history change,
format version, full ordinary build, package refresh, Linux or remote-CI run
occurred. The goal remains active without an external blocker or new percentage
credit. [WAV-04-CONTINUATION](MILESTONES.md#wav-04-continuation) now links the next
representation result to continuity acceptance. Context/part admission, duration
repair, native filtering scale and delivery remain independently actionable.

## Previous checkpoint — weighted saved acoustic blends

The preceding goal turn completed saved-profile replay verification and linked
its backlog prerequisites. This turn implements
[WAV-04-BLENDS](WAV-STUDIES.md#journal-blend-checkpoint): compatible saved acoustic
models combine through actual WFC state/start/end counts, without caches or
retraining. The new companion `pythian.wfc.learning.blend` returns an owned profile;
`pythian.learn blend` persists it through the current report/model contract.

Integer weights 0..64 multiply existing evidence. Exact repeated source ranges
coalesce with added multiplicity; partial overlap and conflicting cache identity
reject. Canonical token/state remapping handles different parent vocabularies'
index order under the same bound palette. Immediate parent hashes and flat
cumulative training contributions survive reload; counts, source ranges and
lineage have explicit budgets. No automatic duration or ratio normalization is
claimed, and no historical reader or additional format version is introduced.

The expanded existing profile fixture compares blended counts against the actual
learner on independently repeated corpora at orders 1, 2 and 4. It covers saved
second blends, differing token order, repeated-parent coalescing, detached lineage,
zero contribution, independent source exclusion, cache conflicts and budget
rejection. Final checked stable/development Win32 and stable Win64 fixtures and
tools pass with no owned warnings; upstream diagnostics remain.

On the saved WAV studies, A + 2B then 2(A + 2B) + 3B retains two source ranges,
129152 raw observations and explicit original-profile contributions 2A/7B.
The second blend contains 517661 weighted observations, 557 samples and 242 states.
Its saved model and 134144-frame audition are byte-identical on all three targets.
Independent native reconstruction from source coordinates matches exactly,
reporting 52 windows, zero immediate repeats and dense mismatch 0.879203157910.
A 3:1 generation-weight edit preserves model bytes, changes source use 68/60 to
98/30 grains and survives another saved replay exactly. Over-budget CLI blending
rejects before altering existing profile/model outputs.

Evidence is under ignored `build/journal-blend-{stable,trunk,win64}/`.
Inventory is 79 core units, 24 companion adapters and 63 fixture programs; the
existing profile fixture was extended. All processes are terminal. No vendor,
index or history changes, full ordinary build, package refresh, Linux or remote-CI
execution occurred. The goal remains active without an external blocker or
additional completion credit.

The mechanical reuse gate for [WAV-04-BLENDS](WAV-STUDIES.md#journal-blend-checkpoint) is cleared.
Next connected work is sustained continuity and diversity across recordings/seeds,
with listener acceptance still unproven. Context/part admission, the known
duration-provider failure, full native filtering scale and current delivery remain
linked independent work. Short diagnostic fragments do not establish genre learning.

## Previous checkpoint — bound saved profiles and reusable palette starters

The preceding goal turn made implementation progress on saved acoustic profiles.
This checkpoint finishes verification and links the resulting prerequisites in
the [milestone backlog](WAV-STUDIES.md#journal-profile-checkpoint).
Core `pythian.learning.binding` fingerprints ordered centers and analysis/timebase;
the companion `pythian.wfc.learning.profile` restores the current report/model
pair with source-range, candidate and actual model geometry checks. The loader
bounds JSON input size, nesting and structure before parsing. These are consistency
checks, not proof of source measurements or semantic compatibility.

`pythian.learn replay` consumes explicit source WAVs matched by hash in any order,
without caches or training. It retains saved selection weights, seeds and join
policy unless overridden. Shared core `RenderJournalSelection` owns EOF padding
and the fixed grain clock. `journals --palette-from` trains a new model using
saved centers and exact analysis/timebase, recording parent digests. The real
242-state long study and distinct 59-state short-source model pass compatibility;
an independently trained short-source palette rejects.

The final checked stable/development Win32 and stable Win64 profile fixtures
and tools pass. Tests cover binding mismatches, malformed/bounded input, Int64
coordinates and partial-EOF rendering. Saved long-source replay matches prior
joined audio exactly across targets. A 3:1 edit survives a second saved replay;
the final parser builds reproduce that weighted audio on all three targets.
Focused final evidence is in ignored `build/journal-profile-{stable,trunk,win64}/final/`;
the parent folders retain starter training and rejection-preservation evidence.
Core binding/selection also compiled independently of companion search paths.
The independent native inspector reconstructs final weighted audio from source
coordinates exactly, retaining 99/29 grains, zero immediate repeats and dense
overlap mismatch 0.912141338803. Owned builds have no warnings; upstream warnings
remain. Documentation paths/anchors, source privacy and LF/whitespace checks pass.

Inventory is 79 core units, 23 companion adapters and 63 fixture programs.
No vendor/index/history changes, historical-format reader, full ordinary build,
package refresh, Linux or remote-CI run are included. All processes are terminal.
The goal remains active, without an external blocker or extra completion credit.
Next connected work is [WAV-04-BLENDS](WAV-STUDIES.md#journal-blend-checkpoint): combine saved
compatible models with explicit weights and lineage, then reuse a derived blend.
Base/part admission, sustained musical continuity, the known duration-provider
failure, full native filtering scale and current delivery remain open.

## Previous checkpoint — bounded waveform join planning

The preceding goal turn implemented independent journal candidate selection and
source weights. This turn advances [WAV-04-CONTINUITY](MILESTONES.md#wav-04-continuity)
with bounded waveform join planning. `NormalizedGrainJoinError` is now shared by
the existing whole-corpus planner and the new core `pythian.learning.continuity`
unit. The latter retains incoming/outgoing probes from source-bound callbacks,
then improves an initial selection without further waveform reads. Equal-token
source swaps can try alternate windows to avoid repeat-constraint traps.

Per-token/segment counts, fixed tokens, locked windows and the initial repeat
ceiling are hard constraints. Optional CLI `--join-passes` and independent seam,
source-switch and center weights expose the policy. Construction and planning
have explicit sample/probe-work caps. The search is deterministic and local;
neither a global optimum nor sustained musical phrasing is claimed.

The equal-weight long-source audition reduces source switches 117 to 53 and
sampled seam mismatch 0.975118 to 0.747173. Independent full-overlap measurement
improves 0.989548 to 0.900159. Source use remains 69/59 grains, immediate repeats
remain zero and duration remains 134144 stereo frames at 16 kHz. The 3:1 and
rotation-732 probes also improve dense mismatch while retaining their original
per-token/source counts. All saved tokens replay, and source-coordinate rendering
reconstructs all three WAVs exactly. See the [paired checkpoint](WAV-STUDIES.md#journal-join-checkpoint)
for complete metrics and hashes. Distinct-window counts decline, one variant's
center distance increases, and only one contiguous link appears across these
auditions; these tradeoffs remain visible rather than claiming musical acceptance.

Final checked stable/development Win32 and stable Win64 fixtures pass the changed
join contracts, locks, replay and work-budget rejection. The retained activity
fixture passes the shared metric extraction. The core planner compiles without
WFC paths. Stable Win32/Win64 long-probe model/audio bytes match; stable/development
Win32 short-source audio matches. With joins disabled, the previous short audition
is byte-identical. Owned builds have no warnings; upstream diagnostics remain.
Evidence is under ignored `build/journal-join-{stable,trunk,win64}/`, with final
focused tools/fixtures/auditions in `current/` and the native inspector in `verify.lpr`.

All processes are terminal. Inventory is 78 core units, 22 companion adapters and
62 fixture programs. No vendor/index/history changes, new saved format or historical
reader, full ordinary build, package refresh, Linux or remote-CI run occurred.
The goal remains active, without an external blocker or extra completion credit.
Next connected work is saved palette/timebase bindings alongside sustained
continuation and dense/listener evaluation. Base/part providers, the known duration
failure, full native filtering scale and current delivery remain open.

## Previous checkpoint — candidate selection and source controls

The previous goal turn made planning progress by linking backlog prerequisites
and blockers. This turn implements [WAV-04-SELECTION](WAV-STUDIES.md#journal-selection-checkpoint)
through the new core `pythian.learning.selection` unit and the existing journal
CLI. Bounded token/segment/time-bin pools retain Int64 source coordinates.
Independent generation weights and deterministic bin rotation preserve the
learned model and tokens; zero weights exclude segments and unavailable tokens
reject. The pool can be reused in memory without retaining its construction
reader or palette. The CLI still retrains each invocation.

The existing two-source model now auditions 62 distinct windows with no immediate
repeats, versus 15 windows and 88 repeats previously. Equal source weights yield
69/59 grains; 3:1 yields 99/29 and 63 windows. Rotation 732 changes windows with
the same 69/59 contribution and unchanged tokens/model. A partial EOF candidate
exposed a clock bug; zero padding to the analysis window now preserves 134144
frames for every variant. Independent disk-model replay and source-coordinate
reconstruction reproduce each corrected WAV exactly. Full results and hashes are
in the [selection checkpoint](WAV-STUDIES.md#journal-selection-checkpoint).

Checked stable/development Win32 and stable Win64 fixtures pass the changed
candidate/weight contracts and retain exact counted-model parity. Final stable
Win32/Win64 equal-weight model/audio bytes match; final stable/development Win32
short-source audio matches. The new core unit compiles without WFC paths. An
excluded-source CLI request leaves all three prior output files unchanged.
Evidence is under ignored `build/journal-selection-{stable,trunk,win64}/`, with
final tools/auditions in `current/`; `verify.lpr` is the licensed ignored native
saved-output inspector. Owned builds have no warnings; upstream diagnostics remain.

No listener acceptance is claimed: equal weighting switches source 117 times,
and no long-source variant retains contiguous source links. Next work is linked
as [WAV-04-CONTINUITY](MILESTONES.md#wav-04-continuity) alongside
[WAV-04-BINDINGS](WAV-STUDIES.md#journal-profile-checkpoint). Base/part providers, the duration
failure, full native filtering scale and current delivery remain open. The goal
remains active, with no external blocker or additional percentage credit.
All processes are terminal. Inventory is 77 core units, 22 adapters and 62 fixture
programs. No vendor/index/history changes, full ordinary build, package refresh,
Linux or remote-CI run occurred. The current diagnostic report replaces its old
representative list; no new saved style format or historical reader was added.

## Previous checkpoint — backlog coordination and journal learning

Backlog coordination now has a linked
[execution order and blocking map](MILESTONES.md#execution-order-and-blocking-links).
Stable child IDs distinguish ready acoustic selection/binding work, independent
context/phrase/duration work, remaining conversion-scale verification and gated
semantic integration. The completed journal prerequisite no longer appears as
work that must be restarted. Final delivery follows the accepted source checkpoint;
preparation can continue throughout. This is a planning-only update, with no new
implementation, validation result or completion credit.

The preceding goal turn made implementation and verification progress on persistent
feature journals. This turn connects [WAV-01](WAV-STUDIES.md#native-rate-scale-checkpoint)'s cache to
[WAV-04](MILESTONES.md#wav-04)'s bounded palette learning, actual counted WFC learning
and an audible source-window path. The goal remains active, with no external
blocker or added milestone percentage credit.

`TAcousticPalette.CreateFromReader` shares farthest-first initialization and eight
Lloyd iterations with the existing array constructor. A repeatable vector reader
supplies positive integer multiplicity; only centers/sums/counts persist across
passes. Existing array entry points retain their 65536-observation limit.
`TJournalTrainingReader` borrows completed compatible journals, rejects overlapping
source ranges and preserves declared segment boundaries and Int64 coordinates.
`LearnJournalAcousticModel` accumulates public WFC state/start/end counts in bounded
storage. Counts exactly represent whole-segment multiplicity, and history crosses
journal batches. Companion state/sample/Integer limits remain unchanged.

`FindJournalRepresentatives` selects a nearest assigned observation per token.
The `pythian.learn journals` command verifies WAV/cache bindings, trains, serializes
and decodes the WFC model, then generates 128 grains. It seeks only selected source
windows into small clips and uses the existing renderer with a headroom check.
The `.wfcs` model uses the existing companion format; `.json` is a training report
with palette/source/analysis bindings and audition coordinates, not another saved
semantic style format. The CLI treats each WAV as one declared recording and
supports sticky `--multiplicity`; the library also accepts explicit nonoverlapping
recording/song ranges. Neither infers song boundaries inside a long mix.

The full prepared source-C cache trains all 128683 observations into 16 palette
tokens and 244 WFC states. Its 128-grain audition is 134144 stereo frames at 16 kHz
(8.384 seconds). The initial stable run takes 49.892 seconds including source
checks and rendering. Stable Win32 and Win64 model/audio bytes are identical; the
final current stable run preserves them. Model SHA256 is
`13774d9001c05a8c6a2d1d4c86a60529449c7f69662efff6dfea23b9fec9d8b5`;
audio SHA256 is `ee0d9da3a45f59dff7d0441ed62619a0acbf9f85774e7be993593b35ea8a065d`.
A separate native operator reads the saved model from disk without training and
replays every generation token. Selected source coordinates reach frame 122473472.
The decoded audio peaks are 0.23828125/0.21612549, with RMS 0.05865511/0.05651867.

A source-C/source-A probe uses 129152 unique observations. Multiplicities 1 and 274
provide 128683/128506 weighted observations, totaling 257189 and yielding 242 WFC
states. The 275 weighted samples represent two actual recordings. Output uses
107 C grains and 21 A grains, despite nearly equal training mass. Its model SHA256
is `9b6266e38bb11db0824596afe2547a6367152f4a99a8c09cb8807878fe440f19`;
audio SHA256 is `d48f14a57d3dbb5b0eebc90c2f7272eb5b68598ff8f5c7b4c521ff46f6723d83`.
Saved-model generation replays exactly. Audio peaks are 0.26287842/0.28482056.
The single-source output uses 13 representatives and repeats the same window in
75/127 adjacent pairs; the weighted probe uses 15 and repeats in 88/127 pairs.
These fixed-seed results identify a real diversity/contribution-control gap.

Checked stable/development Win32 and stable Win64 fixtures match counted models
byte-for-byte to the companion learner for orders 1..4, batch sizes 1/7/13,
declared boundaries, multiplicity and a one-cell segment. Weighted centers match
controlled expanded evidence within 1e-12. Overlapping ranges reject. The original
learner retains prior exact JSON/model output; the short journal path produces
the same model and byte-identical audio on all three targets. A source-only core
compile and core corpus regression pass. Final owned builds have no warnings;
companion/RTL diagnostics remain. Evidence is under ignored
`build/journal-learning-{stable,trunk,win64}/`, with final focused builds in
`current/`; `verify.lpr` is the licensed ignored saved-output inspector.

All processes are terminal. Inventory is 76 core units, 22 companion adapters and
62 fixture programs. The counted adapter retains WFC's 2021 notice and the 2026
adaptation notice; provenance is recorded. No vendor/index or root history changes,
full ordinary build, package refresh, Linux or remote-CI execution occurred.
Original pilot inputs remain unchanged.

Next expand candidate diversity and explicit generated-source controls, then
evaluate declared seeds and recording-level held-out material. Integer training
mass is not an output source quota; one representative per token is not acceptable
evidence of a well-rounded style. Repeated saved blends require compatible palette
and timebase bindings. [WAV-02](MILESTONES.md#wav-02) and
[WAV-03](MILESTONES.md#wav-03) still supply the missing admitted context/part providers.
The fixed feature-hop clock is not learned BPM, and acoustic states are not voices.
Full-length native sinc conversion also remains a separate WAV-01 scale check.

## Persistent feature journal checkpoint — 2026-09-15

The preceding goal turn made concrete progress on long-source feature batches.
This turn implements their persistent storage/recovery boundary and runs it over
the full prepared source. [WAV-01](WAV-STUDIES.md#native-rate-scale-checkpoint)'s journal is now available
for [WAV-04](MILESTONES.md#wav-04)'s bounded learner consumer. The goal remains
active; there is no external blocker and no milestone percentage credit is added.

`TFeatureJournal` stores bounded, checksummed batches bound to exact source hash,
geometry, analysis version and options. Commit precedes progress acknowledgment.
Reopen scans validated records; explicit recovery removes only incomplete final
writes. Complete corruption and changed bindings reject without repair. Readback
retains feature coordinates and values, and duplicate or skipped ranges reject.
This is one current `.pyaf` feature-cache contract, distinct from finished corpus
and style artifacts, with no historical readers or alternate style encodings.

`pythian.learn cache` now opens the source and cache with appropriate file sharing,
hashes source bytes before work and after the invocation, and flushes each accepted
append/recovery. Cache open/create does not truncate existing files. Detected source
changes remove the invocation's new observations while retaining its earlier prefix.
Windows paths execute here; the conditional Unix file/lock path is not yet verified.
File flush and injected process/write recovery are exercised; physical power-loss
durability is not independently claimed.

Two invocations cache the complete prepared source-C WAV: first 2048 observations,
then a fresh process appends 124 batches to reach 128683 observations from
131770456 stereo frames at 16 kHz (approximately 2h17m). Combined local time is
460.605 seconds including source hashing/commits. Sampled peak working set is
7049216 bytes. The completed 17526764-byte journal SHA256 is
`b12aa48d56f2420b388dff8e43cebf6db12604e9deb109b8feb816dc2f5e21b7`.
Its binding uses the headroom-prepared source SHA256
`ff077fb77512a48c359d46c0569025defc22839ba7cd844a479409d8c7edcf89`.
The final current executable reopens it, verifies the entire chain, appends zero
batches and preserves the cache byte-for-byte.

Checked stable/development Win32 and stable Win64 builds pass journal round trips,
duplicate rejection, partial-write recovery, flush failure with an in-doubt complete
record, changed source/options/geometry and corruption rejection. All three reopen
the stable-produced short cache. A physical file truncated by 17 bytes recovers
from index 348, removes 16643 incomplete bytes and regenerates exactly the accepted
short cache. A wrong WAV source rejects without changing it. The original learner
still produces byte-identical JSON/WFC output to the retained earlier executable.
Focused owned builds have no warnings; companion-linked builds retain upstream
diagnostics. Final focused binaries/logs are under
`build/feature-journal-{stable,trunk,win64}/current/`; the source study, cache files,
initial/resume/recovery reports and timing remain in their ignored parent folders.
The long run used the initial tool binary; the final binary adds failure-state
guards without changing the successful encoding and verifies the complete cache.

All processes are terminal. Inventory is 75 core units, 21 adapters and 61 fixture
programs. The new focused fixture is wired into the ordinary build. No full ordinary
build, package refresh, Linux/remote-CI execution, vendor/index changes or root
history changes occurred. Original pilot inputs remain unchanged.

Next implement bounded palette learning and actual counted WFC learning from these
journals. Current palette/companion acoustic APIs cap in-memory corpora at 65536
observations, below this cache's 128683. Carry history across batches and reset at
declared recording/song boundaries; retain explicit source balance and vocabulary
contracts. Bounded source-grain access at Int64 coordinates is also needed for the
audible consumer. [WAV-02](MILESTONES.md#wav-02) and [WAV-03](MILESTONES.md#wav-03)
remain prerequisites for semantic context/part providers. Full-length native sinc
conversion remains a separate WAV-01 scale check. Persistent features are not yet
a learned many-hour musical style.

## Long-source feature batches checkpoint — 2026-09-15

The preceding goal turn made implementation and verification progress on bounded
conversion. This turn extends [WAV-01](WAV-STUDIES.md#native-rate-scale-checkpoint) into long-source
feature extraction. `AnalyzeAudioSourceRange` shares the existing feature engine;
`AnalyzeWaveBatch` exposes bounded observations, Int64 source coordinates and an
explicit next index. One preceding spectrum restores flux on resume without
emitting duplicate context observations. No source history resets at a batch edge.
Whole-result APIs and existing corpus/model budgets remain unchanged.

Checked stable/development Win32 and stable Win64 fixtures pass exact full/batch
parity, arbitrary batch boundaries, partial windows and RF64 positions beyond
32-bit frame coordinates. Existing core and actual WFC corpus fixtures also pass
on stable Win32. The focused core builds have no warnings. No new fixture program,
core unit, maintained archive format or dependency was added.

The full source-C floating WAV contains 131770456 stereo frames at 16 kHz
(8235.654 seconds, approximately 2h17m). Native batches of 1024 emit 128683
observations in 412.719 seconds. A fresh process resumes at observation 126977
using batches of 137; the remaining 1706 feature records match the uninterrupted
tail byte-for-byte. All coordinates and counts are checked natively. The full
feature diagnostic SHA256 is
`123a8530ca59ca6082aedfe02821b7a2397d5f13e940ebd20d7b42af3e11086e`;
the matching tail is
`38bd62766563a018f58df573fb79609e050e6805f8e1e373cd48574bf8b39282`.

Full-source peak is 1.3670556545. Native same-rate PCM16 preparation with a 0.5
ceiling applies gain 0.3657495570 and preserves every source frame. Output SHA256
is `ff077fb77512a48c359d46c0569025defc22839ba7cd844a479409d8c7edcf89`;
the source SHA256 is
`f88587b2ca13890f215e8eadda029d32ccdbc415c2cd11b715dd49ef697b5c77`.
Source decoding/rate preparation was external and retained floating values;
this does not establish full-length native sinc conversion. Sampled process peak
working sets are 7233536 bytes for analysis and 6299648 for conversion.

Evidence and licensed native diagnostic programs are under ignored
`build/wav-long-source/`; focused builds are in `build/wav-batch-{stable,trunk,win64}/`.
All processes are terminal. The diagnostic feature bytes are local comparison
artifacts, not another maintained archive format. Original short pilot inputs
remain unchanged. Inventory remains 74 core units, 21 adapters and 60 fixtures.
No vendor/index or root history changes, full ordinary build, package refresh,
Linux or remote-CI verification occurred.

No milestone points are awarded. WAV-01 next needs durable source/options-bound
checkpoints, interrupted-write recovery and exactly-once observation commits.
[WAV-04](MILESTONES.md#wav-04) then needs compatible vocabulary/transition
aggregation and source balance; accepted semantic providers still depend on
[WAV-02](MILESTONES.md#wav-02) and [WAV-03](MILESTONES.md#wav-03). Full-source
feature extraction is not yet a learned many-hour musical style. The goal remains
active with concrete progress and no external blocker.

## Bounded conversion checkpoint — 2026-09-15

The backlog retains stable [WAV-01](WAV-STUDIES.md#native-rate-scale-checkpoint) through
[WAV-05](MILESTONES.md#wav-05) links, explicit prerequisites and acceptance gates,
and an order of operation. No external blocker currently prevents progress.

WAV-01 now has a bounded preparation checkpoint. `TWavePcmReader` connects the
existing WAVE frame reader to continuous sinc conversion, preserving float peaks.
`StreamResampleFrameCount` handles exact Int64 ceiling duration without a growing
count/rate product. The existing conversion tool streams RIFF/RF64 PCM16, supports
one explicit gain or attenuation-only peak ceiling, reports hashes/levels/counts,
and stages validated output before replacement. Final destination-copy I/O still
has no atomic rollback guarantee. No analysis algorithm or format branch changed.

Checked stable Win32, development Win32 and stable Win64 builds pass the extended
existing stream fixture: huge exact duration/overflow, borrowed WAVE position,
uneven stereo blocks, permanent failure and the existing signal/alias checks.
All three convert the previously rejected 30-second 48-kHz stereo source to
480000 frames at 16 kHz with byte-identical SHA256
`990453cae6f373898cce338540c8b0afd14c4e1833ba51d98e874b2d87de479e`.
Stable block sizes 127 and 4096 replay exactly. The first stable run takes
32.35 seconds locally; this is not a many-hour throughput assessment.

The existing 16-kHz float probe preserves peak 1.0273228884; a 0.5 ceiling applies
gain 0.4867018984, after which separation exports with maximum reconstruction
error 2.24e-8. This probe used external rate preparation before this checkpoint.
Same-rate PCM identity, attenuation-only behavior, explicit gain and unchanged
accepted output after headroom/option rejection pass. Evidence is under ignored
`build/wav-convert-{stable,trunk,win64}/`; original pilot inputs remain unchanged.

This checkpoint is supporting implementation/evidence progress, with no milestone
points awarded. Multi-hour conversion/analysis, throughput, resumable ingestion
and overlap accounting remain open in WAV-01; context, parts, style aggregation
and delivery follow the linked backlog. Current inventory is 74 core units,
21 companion adapters and 60 fixture programs. No full ordinary build, refreshed
package, Linux or remote CI evidence is claimed. All checkpoint processes are
terminal; vendor/index state and root history are unchanged.

## Initial WAV study checkpoint — 2026-09-15

The initial mixed-WAV source study is complete and its observations are now the
[milestone backlog](WAV-STUDIES.md#initial-wav-source-passes--2026-09-15). Nine
30-second sections span early/middle/late positions in three long sources.
Source assets, extraction/preparation records, hashes, native reports, saved
corpora and auditions remain in ignored `build/wav-source-study/`. Documentation
describes WAV-source behavior using neutral source labels.

The backlog now uses stable dependency links: [WAV-01](WAV-STUDIES.md#native-rate-scale-checkpoint)
preparation/ingestion first; [WAV-02](MILESTONES.md#wav-02) context and
[WAV-03](MILESTONES.md#wav-03) parts can progress alongside each other, with
independent corpus aggregation in [WAV-04](MILESTONES.md#wav-04). Semantic style
integration consumes their accepted providers. [WAV-05](MILESTONES.md#wav-05)
delivery preparation can proceed throughout; final verification follows the
accepted source. Each item records its present blocker or acceptance gate.
No external blocker prevents the next action. These are dependencies within
existing outcome allocations, not additional milestones or earned points.

Checked FPC 3.2.2 Win32 builds of the existing native operators perform levels,
tonal/global-pulse inspection, onset cues, local pulse tracking, independent
left/right periodic-pitch inspection and three separation probes. Of these 57
invocations, 56 complete and one separation export rejects PCM16 headroom. An
additional native offline 30-second stereo conversion rejects its tap-visit
budget; external preparation supplies the fixed 16-kHz stereo PCM16 inputs.
Five prepared sections reach full scale. A separate floating-point preparation
probe measures peaks 1.0273/1.0172, so input quantization/headroom is an explicit
confound, not a defect assigned solely to separation or inference.

The pulse/key and pitch reports retain substantial uncertainty: two sections
have no global pulse candidate, local tracks report seam issues in eight, and
per-channel periodic candidates range from 0 to 71 of 120 inspected cells.
The quarter-second inspection clock is authored; no mixed source is declared
monophonic and no candidate is promoted to an accepted key, tempo or voice.
There are no reference annotations or listener acceptance for these inputs.

Three per-source acoustic/activity corpora and a combined corpus learn, save,
reload and generate through actual WFC. The eight free/activity-constrained
auditions each contain 128 grains / 134144 frames at 16 kHz (8.384 seconds).
A native report summary checks loaded-without-learning status, grain counts and
the selected onset/sustain locks. Combined saved generation replays byte-for-byte
with SHA256 `7e8e84639a6a6635b0b43e47e382910a55d7a16236e87b6f9d7f030b64ab3af3`.
That free run improves the planner seam metric from 0.9340 to 0.1835 but retains
36 source jumps. Source-C free generation uses one excerpt for 119/128 grains;
this fixed-seed concentration motivates balance/diversity work, not a conclusion
about the entire generator distribution. Several auditions reach PCM16 full scale.

The accepted end state is now explicit in the profile and
[style architecture](LAYERED-STYLE.md#learning-a-style-from-many-hours): learn
high-level chillwave, stoner rock and lofi styles from many hours across recordings,
save reusable musical providers and use derived styles in later selective blends.
The labels are caller-provided. This pilot learns short acoustic/activity corpora,
not those complete genre profiles. Long-source bounded ingestion, resumable
aggregation, source balancing, semantic part learning and recording-level held-out
evaluation remain open. Existing WFC passes and the current format policy apply.

The preceding goal turn made implementation and measured-evidence progress. This
checkpoint adds the requested initial observations and backlog; it makes no core
algorithm change and awards no milestone points. The 89.8% historical engineering
ledger must not be read as many-hour style-learning readiness. Next work starts
with preparation/headroom and bounded ingestion, then the connected context,
phrase/part and corpus-style gaps. The requested pilot stops before those repairs.
No new tests, format branch, vendor/index change, root commit/push, full ordinary
build, package refresh or remote CI occurred. All acquisition and study processes
are terminal. Logs and per-pass exit ledgers are in the ignored study folder;
`observations-sections.csv` and `observations-generation.csv` hold the native
numeric summaries. The earlier annotated held-out recordings remain unused.

Before this study, an ignored native region diagnostic compared the development
annotations with inferred intervals in `build/phrase-segmentation-probe/`. It
exposes excess splits in held notes and missed repeated attacks, but supplies no
new segmentation algorithm or acceptance credit. That investigation remains part
of the recorded-phrase backlog after source preparation is addressed.

## Preceding support-bin ending checkpoint — 2026-09-15

`GatePitchRegion` now retains the detected attack and ends at the last supporting
pitch hop bin plus bounded optional padding. Summaries retain each note vote's
support extent without changing raw measurements. Unknown or malformed support
rejects. The phrase operator's existing `--region-study` adds a separate gated
condition, proposed note boundaries, frame scores and `.gated.wav`; references
never enter that inferred audio. There is no new archive family or learned-style
provider. `EvaluatePitchIntervalFrames` measures explicit nonoverlapping intervals
at unchanged raw-track centers, retaining ambiguity, unsupported range and unknown
gaps rather than inventing measured silence.

Default development flute/violin full-note F1 rises from 0.6667/0.5938 to
0.6901/0.6042. False pitches in reference rests fall from 99/44 to 70/31 centers,
but correct coverage falls from 74.92%/77.37% to 73.51%/75.85%. Precision becomes
92.97%/97.83%. All remain below the complete acceptance requirements. The policy
stays experimental and the held-out set remains unused. A prior 20-ms onset energy
window probe also failed; the detector default remains 5 ms. Full results and
audition hashes: [ending study](PHRASE-EVALUATION.md#support-bin-endings--2026-09-15).

Checked stable/development Win32 and stable Win64 pass the pitch fixture and
maintained development region workflow. Forty WAV/model comparisons replay
exactly; twelve native JSON comparisons retain identical discrete evidence with
raw/vote measurement differences <= 1.43e-12. Original raw/source and default
detected-region audio retains its bytes. Gated output/input collision rejection
preserves all five prior artifacts. Evidence is in
`build/phrase-boundaries-{stable,trunk,win64}/`; the maintained output directories
remain `build/recorded-phrases-{compiler}-{cpu}-{os}/`. All processes are terminal.
No owned warnings in the pitch fixture/operator builds. Current package refresh,
ordinary full build, remote CI, root commit/push, index and vendors are unchanged.

The preceding milestone review is progress: it updated authoritative scope and
acceptance direction. This implementation checkpoint adds measured evidence of
the ending/coverage tradeoff but earns no new milestone credit. The provisional
ledger remains **89.8% engineering scope**, with **10.2 points** across five open
outcomes, not a measured percentage of general song understanding. Next improve
event segmentation jointly with pitch support, protecting repeated notes and real
octaves while reducing spurious splits and missed attacks. Endpoint trimming alone
is insufficient. Keep the saved 32-span duration-provider failure visible and
preserve independent WFC layers, repeatable blends, core synthesis priority and
one current native format per artifact. See
[milestones and direction](MILESTONES.md#direction-for-the-next-work-package).

## Preceding region inference checkpoint — 2026-09-15

`pythian.pitch.regions` now summarizes raw periodic evidence inside independent
candidate-event intervals. It retains every note's energy share, mean tuning and
deviation, periodic coverage, raw admitted count and an explicit admission
decision. RMS normalization and weighted incremental variance bound numerical
work and avoid cancellation. Defaults require three periodic windows, 50%
periodic coverage, 75% energy share and a mean within 25 cents. No raw estimate,
per-window tuning threshold or archive changed. Explicit event boundaries protect
real octave changes; this API does not discover those boundaries or voice roles.

`EvaluatePitchNoteIntervals` scores inferred note intervals separately from raw
track measurements. The native phrase operator's optional `--region-study` reports
reference-boundary and detected-onset conditions separately. Only detected-onset
hypotheses feed its additional `.regions.wav` audition. The maintained optional
workflow exposes `-RegionStudy`; its WFC learner still consumes raw measured
duration evidence, never reference-boundary hypotheses.

On development Spring flute/violin, detected-region full-note F1 improves from
0.6114/0.5217 to 0.6667/0.5938 with the default pitch width. Onset F1 becomes
0.7018/0.7917. Both still miss the full-note target. Known-boundary diagnostics
score 0.8639/0.8875 full-note F1, but are not end-to-end accuracy. Default event
planning supplies 303/305 intervals; reliable note boundaries and physical
offsets remain the principal integration gap. The held-out set remains unused.

The octave investigation found real lower periodic components during flute
attacks, so the physical estimator was not patched to double notes. Existing
harmonic preprocessing did not improve full-note F1. Native diagnostics are in
`build/phrase-octaves/`; protocol and detailed results are in
[recorded phrase evaluation](PHRASE-EVALUATION.md#musical-note-regions--2026-09-15).

Checked stable/development Win32 and stable Win64 pass the region API, explicit
note scorer and maintained study workflow. Study audio and model text replay
exactly across targets (38 exact artifact comparisons); ten JSON comparisons
retain identical discrete evidence with measurement differences <= 1.43e-12.
The native comparator is under `build/phrase-regions-stable/`. Original raw/source
auditions remain identical, and invalid study options/input collisions preserve
accepted outputs. All processes are terminal. Counts are 73 core units,
21 adapters and 60 fixture programs. No current package refresh, ordinary full
build, remote CI, root commit/push, index or vendor change occurred.

Next improve source-derived note onset/offset proposals using these separate
contracts, with counterexamples for weak attacks, noise, repeated notes and real
octave jumps. Keep region hypotheses outside saved-style learning until recorded
acceptance is demonstrated. The 89.8% scope ledger earns no new points here.

## Preceding recorded-phrase baseline — 2026-09-15

The native `pythian.pitch.evaluate` unit and `pythian.phrase.wav` operator now
compile and pass scoring checks for stable labels, short-run rejection, absolute
reference coordinates, rests, ambiguity, unsupported range and one-to-one note
boundaries. The core has no companion dependency. Reports retain fingerprints,
measurement policies, pitch rejection causes and onset/offset matching outcomes.
`tools/recorded-phrases.ps1` orchestrates pinned optional inputs, native evaluation
and actual saved WFC duration learning/generation. Its default development set
keeps held-out recordings unused. The ordinary build compiles the new operator;
scoring checks extend the existing pitch fixture.

Development Spring flute/violin first-30-second excerpts both fail the predeclared
quality targets. Default coverage/precision are 77.57%/92.19% and 71.69%/99.61%;
onset F1 is 0.6812/0.7246 and full-note F1 0.6114/0.5217. The 110-ms diagnostic
window lowers both note scores. All 116 default flute wrong active windows are
octave errors. Violin's 704 unknown active windows comprise 304 no-period, 349
tuning/admission and 51 short-run rejections. The estimator and thresholds remain
unchanged; these results guide octave/fragmentation work before held-out evaluation.
See [protocol, results and native commands](PHRASE-EVALUATION.md).

Encoded PCM16 excerpts separately learn 135/119 pitch runs in 245/238 explicit
spans. Saved actual WFC models generate five/four audible notes in eight-span
fragments. Evaluation uses floating resampled samples; learning fingerprints and
reads their encoded excerpts, so their near-threshold admission can differ. This
does not resolve the 32-span style-provider failure or establish joint recorded
part behavior. No milestone points are awarded; the 89.8% ledger stays provisional.

Checked stable/development Win32 and stable Win64 pass the development workflow.
Cross-target comparison found Single intermediates in the new F1 helper on
Win64; explicit Double arithmetic fixes it, with a focused precision oracle.
Final scoring and development measurements pass on all three targets. Evaluation
reports, all WAVs and saved model text replay exactly (38 exact artifact
comparisons). Two raw Win64 learner reports retain identical discrete evidence
with floating measurement differences <= 1.43e-12, verified by the native
`build/phrase-evaluation-stable/compare-evidence.lpr` helper. Input/output collision
and malformed-reference rejection preserve all three accepted operator artifacts.
Evidence: `build/recorded-phrases-{compiler}-{cpu}-{os}/` and
`build/phrase-evaluation-{stable,trunk,win64}/`. Counts are 72 core units,
21 adapters and 60 fixture programs. Existing package, full ordinary build and
remote CI evidence retain their older scope. No vendor or root index changes.

## Preceding milestone review — 2026-09-15

Milestone review: retain the provisional 89.8% engineering-scope ledger (about
90%), with no new credit from planning or unfinished evaluation work. The next
five open outcomes are recorded phrase reliability (+2.0 points), dependable
context (+2.8), joint recorded-part style integration (+2.4), integrated synthesis
quality (+1.0) and current reproducible delivery (+2.0). Their 10.2-point total
preserves the previous allocation; phrase and joint-part work divide the former
4.4-point voice outcome. See [acceptance and direction](MILESTONES.md).

The [recorded phrase protocol](PHRASE-EVALUATION.md), selected cached inputs,
`src/pythian.pitch.evaluate.pas` and `tools/pythian.phrase.wav.lpr` are present.
The evaluator/operator remain unvalidated work in progress, with no completed
recorded phrase results found in this review. Validate the scoring, establish a
development baseline, and evaluate a fixed policy on held-out recordings before
crediting reliable learning. Reassess scope if observed errors require more work;
general song-style learning has no defensible measured completion percentage yet.

This planning review inspected existing terminal stream/instrument evidence and
the current worktree. Only milestone/work documentation changed; no implementation,
new build, audio evaluation, package refresh, Git index or vendor change occurred.

## Preceding bounded-stream and instrument checkpoint — 2026-09-15

`pythian.synth.stream.TFrameToneStream` now connects finite native tone plans to
the existing scheduler with bounded sample reads. Exact start/end preflight
includes release overlap, stable input order and simultaneous voice/frame-work
limits. Future source objects are created only at their start frames. The stream
retains bounded active playback and at most 2048 returned frames per call; tone
records and event indices scale with the bounded input event count. Definitions
remain borrowed from the owned instrument bindings. Invalid reads are retryable;
source failures poison the stream without publishing a partial block.

Musical planning now bounds events independently of complete PCM storage.
Offline rendering retains its original sample and visit budgets. The instrument
consumer streams the mix and stems through the sequential WAV writer, stages
complete encoded files and hashes them with fixed buffers before publishing.
`--block-frames` exposes read sizes 1..2048; reports retain mixing policy, peaks,
simultaneous voices and weighted frame work. No native format generation changed.

The previously rejected authored WFC context passage now renders 88 notes /
791022 stereo 44100-Hz frames, with a mixed peak of 0.0404041, at most 12 voices
and 624 weighted voice-work units per frame. A melody-envelope edit preserves
bass/chord WAVs, timbre bindings and complete MIDI. The full maintained recorded
workflow passes stable Win32 and regenerates a separate sustained 88-note /
729281-frame audition using admitted key/tempo context and authored phrase training.
Its 127-frame and 2048-frame consumer reads replay exactly. The isolated-note
duration model still cannot generate a 32-span phrase; that learning gap remains.

Checked stable/development Win32 and stable Win64 pass core scheduler/stream,
music and instrument fixtures without companion search paths, plus saved-style
fixtures and the sustained consumer. Irregular core reads replay exactly; 48
cross-target WAV/MIDI/JSON files match byte-for-byte. The short streamed output
differs from its preceding offline counterpart by at most one PCM16 step because
scheduled mixing accumulates Double values before final Single conversion.
A native 129-note simultaneous MIDI case admits each 43-note stem but rejects
the mixed stream's 128-voice limit; all six accepted outputs survive and staging
files are removed. Long musical planning admits a 40-million-frame extent while
the unchanged offline renderer rejects full-clip allocation.

Evidence: `build/instrument-stream-{stable,trunk,win64}/`, including core
`schedule-run.log`, `music-run.log`, `music.instrument-run.log`, `style-run.log`,
`operator-status.log`, `block-replay.log`, `offline-comparison.log`, and stable
`recorded-workflow.log`, `full-recorded-status.log`, `replay.log`,
`late-admission-rejection.log`, `rejection-status.log` and the native
`limit-source.lpr` evidence generator. All processes are terminal. Counts are
71 core units, 21 adapters and 60 maintained fixture programs. No vendor changes,
root commit/push, package refresh, full ordinary build or remote CI run occurred.

This completes the reusable measured-instrument milestone for declared roles:
saved second blends, independent sound choices, detached ownership, accepted
WFC music and sustained audible rendering now compose through public APIs.
Its planned 4.2 points bring the engineering assessment to 89.8, rounded 90%;
the four open outcomes retain 10.2 points. This includes preceding timbre/envelope
work and does not separately award the fundamentals point for streaming.
Next: referenced multi-note recordings with predeclared admission/error limits,
repeated/held notes, rests and learned phrase/joint behavior through saved WFC
passes. See [outcome assessment](MILESTONES.md),
[stream contract](SCHEDULING.md#bounded-tone-streams) and
[instrument consumer](WAVE-STYLE.md#independent-measured-instruments).

## Preceding independent-instrument checkpoint — 2026-09-15

The companion now provides `TStyleInstrument`: core keyboard/velocity zones with
independent saved timbre/envelope selections, owned measured wavetable factories,
cloned authored automation/envelopes and retained separate profile identities.
Profiles can be freed after construction. Instruments must outlive plans/playback;
custom factories without measured overrides remain explicitly borrowed. A fixed
construction rate prevents accidental reinterpretation of frame envelopes in
`PlanStyleNoteTones`. All declared keys are admitted, overlaps use core layering,
and missing selected evidence rejects. No new archive or historical reader exists.

The native `pythian.instrument.style` consumer binds MIDI channels 0/1/2 to
bass/chords/melody across tracks, preserves original MIDI bytes, and exports a
mixed WAV, three stems and a provenance report. The maintained recorded workflow
now generates accepted music through actual WFC passes, then renders independent
recorded C/A and second-blend instrument choices. A melody-envelope-only edit
preserves sounding bass/chord WAVs, timbre bindings and MIDI, while changing the
melody and mix. Both variants have five notes and 37370 stereo 44100-Hz frames;
natural release tails remain explicit and can overlap rests.

Checked stable/development Win32 and stable Win64 pass the extended existing
profile fixture and recorded stem controls. Twenty-four cross-target mixed/stem
WAV, MIDI and JSON comparisons are byte-identical. Invalid profiles, path
collisions and excessive workloads preserve accepted outputs. The full maintained recorded workflow
passes stable Win32. Ownership checks compare against an independently assembled
source after profiles and authored controls are freed, exercise key/velocity
boundaries and overlaps, and reject partial construction and mismatched rates.
Evidence: `build/style-instrument-{stable,trunk,win64}/`, especially `style-run.log`,
`controls.log`, `status.log`, `recorded-status.log`, and stable
`recorded-workflow.log` / `full-recorded-status.log`, `replay.log` and
`rejection-status.log`; `final-status.log` covers the final consumer on each target.
Counts are now 70 core units,
21 adapters and 60 fixture programs. Core source and vendors are unchanged.

Two larger auditions did not pass: this isolated-note style cannot satisfy a
32-span duration prefix, and these instrument choices on the longer authored WFC
context passage exceed the offline 100-million-visit render budget. Next, connect
the instruments to bounded streaming playback without relaxing core work limits,
then tackle referenced recorded phrases. These failures constrain the evidence;
the 86% planning estimate is retained. Packages/clean-clone evidence remain older.
See [instrument ownership and consumer](WAVE-STYLE.md#independent-measured-instruments)
and [outcome direction](MILESTONES.md).

## Preceding saved-envelope and planning checkpoint — 2026-09-15

Milestone reassessment now supersedes the unchanged 65% planning baseline.
The evidence-backed planning estimate is approximately 86% (65 + 20.6 weighted
points), with 14.4 points assigned to five outcome milestones. These estimates
describe engineering scope, not measured musical accuracy or ecosystem adoption.
See [current assessment and direction](MILESTONES.md). Next implementation starts
with reusable measured instrument behavior inside the current style contract;
avoid further isolated feature additions that do not close one of those outcomes.

The latest planning review retains that estimate after checking the saved-envelope
and delivery evidence. The [immediate acceptance result](MILESTONES.md#immediate-acceptance-result)
now defines a cohesive per-role timbre/envelope consumer and paired native
auditions: edit melody envelope selection while preserving bass/chord stems,
timbre recipes and accepted WFC music/MIDI. This review updates the direction;
that consumer is not yet implemented. The next five outcomes still total 14.4
points, with no extra credit for this documentation update.

Saved styles now retain measured amplitude envelopes as a fourth independent
source-weight vector, alongside rhythm, pitch and stationary timbre. Raw RMS
points, source coordinates, window/gate and admission policy survive source
creation, weighted blends, a second derivation and decode. The core validates
detached measured evidence and blends linear held/release components on their
retimed knot union, with positive release tails and explicit source/knot budgets.
There is no time stretching or new archive family. Superseded development blends
must be regenerated; no historical reader was added.

`learn-envelope`, optional final envelope weights on `blend-layers`, and inspect
expose the saved dimension. `CopyGateEnvelope` returns owned native definitions;
fixtures bind different saved envelopes to independent voices after profiles are
freed. The current voice operator shares one selected envelope across its three
authored roles. Its existing duration articulation still suppresses tails in
unknown/silent spans. Source-role inference is not implied by this assignment.

The maintained recorded workflow passes on stable Win32. Bassoon C/A measurements
use their complete converted 8000-Hz recordings, declared gate 1023, channel 0,
256-frame windows and tail ratio limit 0.05. Stationary timbre remains weighted
1:1 while the saved second blend uses C:A envelope weights 2:1; an envelope-only
edit selects A. Both produce five notes / 19845 stereo 44100-Hz frames. Their
actual key/tempo/performance and voice decisions, MIDI, preview and every harmonic
recipe coefficient remain identical while final stereo audio changes.

Checked stable/development Win32 and stable Win64 pass the extended profile
fixture, recorded cross-loading and independent saved-recipe/MIDI re-rendering,
which is exact for both recorded outputs. Twelve cross-target WAV/MIDI/preview
comparisons match byte-for-byte. Focused tests cover unequal release lengths,
envelope-only sources, coalesced weights, detached raw evidence, forged window
coordinates, missing selected evidence and per-voice rendering independence.
Wrong WAV identity and stricter tail limits preserve accepted profiles. The
standalone core envelope fixture passes without companion paths; preceding saved
timbre audio/MIDI/preview remain byte-identical after current-schema regeneration.

Evidence: `build/style-envelope-{stable,trunk,win64}/`; stable
`recorded-full-status.log`, `recorded-workflow.log`, `envelope-controls.log`,
`replay.log`, `rejection-status.log`, and each target's `final-status.log`.
The final stronger timbre-preservation check runs separately after the full
recorded workflow. No new full ordinary build or ZIP refresh is claimed.
All jobs are terminal; counts remain 70 core units, 20 adapters and 60 fixture
programs. Milestone 1 advances, but its full 4.2-point outcome is not awarded.
Next: a cohesive consumer with owned, independently selected timbre/envelope
bindings per voice. See [saved envelope contracts](WAVE-STYLE.md#saved-measured-envelopes).

## Preceding measured-envelope and assessment checkpoint — 2026-09-15

`TEnvelopeTrace` now measures detached rectangular-window RMS evidence from one
explicit WAV region/channel, retaining raw levels and source-frame coordinates.
It creates peak-normalized held/release curves with a declared gate, minimum RMS
and final-window/gate RMS limit. It rejects silence, rising releases above the
gate, excessive truncation and collapsed retimed knots. The final partial window
uses only its real samples. RMS includes DC; the API does not infer note boundaries
or isolated voice roles. No persisted envelope dimension has been added yet.

The native source operator transfers this measured envelope onto a sine source
or imported MIDI, reporting source SHA256, coordinates, raw RMS points and policy.
At 8000 Hz, complete converted bassoon C/A recordings admit gate 1023, channel 0,
256-frame windows and a 5% tail ratio limit. Their single-note auditions render
31914/27858 stereo frames at 48000 Hz. Applied to the same five notes from the
recorded style's second blend, they render 40676/36620 frames with independent
25776/21720-frame releases. The envelopes differ; MIDI input retains hash
`0f23b73b3caac8e0d23ee1d5210f413da2f2640d93f9e1ed47beea097dc51bff`.

Checked stable/development Win32 and stable Win64 pass control/source/instrument
sequence fixtures plus controlled and recorded envelope auditions. Twelve source
and audio comparisons match byte-for-byte. Stricter tails, rising releases and
same-input output requests preserve accepted files. The maintained core/recorded
envelope blocks pass separately; default and harmonic-fitting source auditions
retain their preceding hashes. An inherited MIDI report incorrectly described
zero release and measured periodic timbre for this new mode; its envelope-specific
wording is corrected and audio replays unchanged on all three targets.

Evidence: `build/measured-envelope-{stable,trunk,win64}/`, especially
`status.log`, `operator-status.log` and stable `maintained-status.log`,
`cross-target.log`, `rejection-status.log`, `replay.log`. All jobs are terminal.
The full core build below and source ZIPs retain their earlier scopes. Counts
remain 70 core units, 20 adapters and 60 fixture programs. No format generation,
historical reader, vendor edit, commit or push was added. See
[measured amplitude contracts](MODULATION.md#measured-amplitude-envelopes).

## Preceding gated-envelope checkpoint — 2026-09-15

The shared native renderer now accepts an optional `TGateEnvelope`, composed
from independently authored held/release automation curves. Construction and
playing tones own detached clones; instruments and planned records borrow the
definition. Note-off captures the actual held level, including early scheduler
release. Exact custom tails replace the inactive ADSR duration, and curve depth
participates in work admission. Default ADSR remains available per layer.

The existing instrument consumer combines both envelope types and accepts optional
MIDI through the native decoder. Its authored phrase renders 16 notes / 20 layers /
91728 stereo frames at 44100 Hz. Notes from the recorded saved-style second blend
render five notes / five layers / 19845 frames through this instrument. Those
notes came from the companion's existing WFC passes; the envelope is authored,
not learned from the source recording. The maintained core build now runs both
the authored phrase and an imported MIDI audition.

Checked stable/development Win32 and stable Win64 pass the extended control
fixture and instrument auditions. Focused development Win32/stable Win64 checks
also pass core, source, scheduler, instrument and instrument-sequence fixtures.
Independent stereo arithmetic checks cover held and release values, exact extent,
seconds/frame agreement and detached scheduled early release. Oversized tails,
invalid release endpoints and insufficient scheduler work reject before admission.
Four cross-target audition comparisons match byte-for-byte. Same-path and
malformed MIDI requests preserve accepted files.

The rebuilt stable WFC consumer loads the recorded current style and passes its
actual preview/MIDI verification plus the independent saved-timbre audio check.
Its stereo WAV, MIDI and preview remain byte-identical to the previous checkpoint.
Evidence is under `build/gate-envelope-{stable,trunk,win64}/`, including stable
`cross-target.log`, `rejection-status.log`, `companion-status.log`, `replay.log`
and `example-status.log`. The complete maintained stable Win32 `-CoreOnly`
workflow passes; its newly added instrument block also passes separately.
Six preceding ADSR audition WAVs retain their SHA256 identities. See
`core-workflow.log` and `core-status.log`. No authored compiler warnings were
reported; companion compilation retains its upstream generics warnings. All jobs
are terminal. Retained dependencies are clean; branch/index state is preserved
without commits or pushes. Existing source ZIPs predate these additions.

This is a synthesis foundation beneath the saved-style/voice stack. Recorded
envelope admission, voice roles and reusable learned envelope blending remain
open, as do broader delivery/target gates. No new unit, fixture program, file
format or compatibility reader was added; counts remain 70 core units, 20
adapters and 60 fixtures. No milestone percentage is awarded for this increment.
See [gated envelope contracts](MODULATION.md#gated-envelope-curves).

## Preceding saved-timbre checkpoint — 2026-09-15

The previous turn added and verified native harmonic fitting. Stationary timbre
now persists as an optional dimension of the current WAV style, with selected
source interval/channel, fit coefficients and diagnostics, explicit admission
limits and measurement policy. Source creation shares the native fit geometry
preflight; evidence and returned recipes are detached. The existing profile now
has independent rhythm, pitch and timbre source weights. `CreateBlendLayers`
supports selection, weighted mixing, omission and sources active only for timbre.
Repeated derivations retain the existing bounded ancestry and reject conflicting
measurements of the same source. Superseded development blends are regenerated;
no historical reader, new file format, unit or fixture program was added.

The resulting recipe averages harmonic magnitudes with zero sine phase and DC,
retaining amplitude without cancellation from unrelated recording phases. The
native `learn-timbre` operator binds actual WAV identity/geometry before fitting;
`blend-layers` and `inspect` expose the dimension. The voice operator consumes
saved timbre after musical solving, retaining authored per-voice envelopes,
filters, gain and pan. Actual WFC reference preview keeps its original oscillators.
This is a static synthesis dimension, not an inferred temporal timbre model or
separate instrument identity for each voice.

Checked stable/development Win32 and stable Win64 pass core/source/style fixtures,
the maintained controlled block, saved recorded-style cross-loading and timbre
controls. The maintained recorded workflow passes stable Win32. Two selected
8000-Hz bassoon intervals admit relative errors 0.04797157 and 0.15076701; their
weighted second derivation voices five notes / 19845 stereo frames. The controlled
workflow voices 32 spans / 75 notes / 192937 frames. Timbre-only selection retains
exact key/tempo/performance and voice models/states, MIDI and reference preview,
while final stereo audio changes. All 24 cross-target WAV/MIDI/preview comparisons
match byte-for-byte.

Independent saved-recipe/MIDI re-rendering is exact for the recorded case and
within one PCM16 step for the controlled case. The initial exact-byte assertion
exposed simultaneous-note ordering and Single mixing roundoff; the checker now
compares complete audio with that explicit bound, retaining exact MIDI/model/state
checks. Wrong WAV identity and stricter residual admission preserve the accepted
profile. No authored compiler warnings were found. All jobs are terminal, retained
dependencies are clean, and `hello-pythian` remains unchanged without commits or
pushes. Counts remain 70 core units, 20 adapters and 60 fixture programs.

Evidence: [saved timbre](WAVE-STYLE.md#stationary-timbre-and-rendering),
`build/style-timbre-{stable,trunk,win64}/`; `final-status.log`, stable `replay.log`,
`recorded-status.log` and `rejection-status.log`. Full ordinary-build and source
ZIP evidence remain previous checkpoints. This closes stationary timbre's saved
blend/rendering gap; evolving envelopes, automatic region admission, voice roles
and the broader original objective remain open. No automatic percentage increase
is assigned to the new dimension or its fixtures.

## Preceding harmonic-fit checkpoint — 2026-09-15

The previous turn completed current clean-clone build/package evidence. This turn
extends `pythian.source.wavetable` with reusable harmonic fitting across arbitrary
multi-period WAV intervals. Streaming QR jointly fits DC and signed sine/cosine
coefficients at a supplied fundamental. Detached recipes feed the existing table
and morph factories; AC/residual RMS expose stationary-model limits. Work,
source Nyquist, numerical rank and factory coefficient bounds reject before
publishing a candidate. No new unit, fixture program or file-format generation
was introduced: counts remain 70 core units, 20 adapters and 60 fixtures.

The native source operator accepts declared frequency or the existing periodic
estimator with an independently selected pitch-window width. It enforces explicit
AC/error admission before output and uses the existing note/MIDI renderer. Checked
stable/development Win32 and stable Win64 pass the extended source fixture and
controlled/recorded listening paths. Fourteen compared WAVs match across targets;
prior default/cycle audio remains unchanged. Invalid error/width policies preserve
accepted output. The fixture initially omitted its older cycle WAV when supplied
two output paths; its argument guard was corrected and all three targets rerun.

Six recorded staccato samples exceed the initial 25% relative-error limit over
the common 110 ms interval. Failures remain evidence; the threshold was not
widened. A subsequently selected 1500-frame bassoon C interval, using 4851 frames
for frequency measurement, fits at 130.916145 Hz with 4.780484% relative error.
Its recipe voices five notes / 21600 stereo frames from the recorded saved second
blend. The full maintained recorded pitch/style/WFC workflow passes stable Win32.
The controlled changing-context MIDI audition retains 45 notes / 252000 frames.
This extends measured timbre rendering, without admitting complete instrument
envelopes, automatic stable-region selection or a saved learned timbre dimension.

Evidence and contracts: [harmonic fitting](SOURCES.md#harmonic-fitting-across-a-wav-interval),
`build/harmonic-fit-{stable,trunk,win64}/`; stable `maintained-status.log`,
`replay.log` and `rejection-status.log`. All jobs are terminal. The preceding full
clean build and ZIPs predate this addition; focused affected consumers were
verified. The original objective and provisional allocations remain open.

## Preceding source delivery checkpoint — 2026-09-15

Current source delivery now includes the recent performance API, local tonal
regions, shared FFT and harmonic/percussive separation. An isolated Git snapshot
of 270 owned files and the two retained gitlinks was cloned into an empty build
environment; pinned Athena and WFC were fetched from their declared remotes.
The complete maintained `tools/build.ps1` workflow passed on checked stable FPC
3.2.2 Win32, including WFC learning and generation. The clone remained clean.
All 210 implementation, test, tool, example and package files still match the
workspace; delivery-record updates follow the tested snapshot.

Both source ZIPs were built and verified from that clone. The core package
contains 70 owned units / 80 files and five examples, checked on stable Win32.
The companion contains 90 owned units / 200 files and seven examples, checked on
stable Win64. Extraction, every content hash, complete owned-unit compilation and
every bundled example pass. An external consumer using only extracted core
source also passes the separation/FFT fixture on development FPC 3.3.1 Win64.
The packages are dependency subsets of the current library, with no additional
historical format support.

Evidence and ZIPs are under `build/delivery-current/`; see [delivery](PACKAGING.md)
for snapshot revision, hashes, commands and limits. Full build and package jobs
are terminal. The working branch, index and dependency checkouts were preserved;
the validation commit exists only in the isolated ignored snapshot. No root
commit or push was made. Linux and remote CI remain unverified, and the complete
source is not yet in the working repository's published history. This closes the
stale local build/package evidence gap without claiming completion of recorded
accuracy, polyphonic voice learning or the original broader objective. The
provisional milestone allocations remain unchanged.

## Preceding spectral separation checkpoint — 2026-09-15

The previous turn was progress: local tonal evidence entered saved styles and
actual voice generation. This turn adds a reusable native spectral separation
stage and shared forward/inverse FFT. `pythian.fourier` extracts the existing
analysis butterfly with checked geometry, detached arrays and inverse scaling.
`pythian.separation` owns harmonic/percussive clips, uses linked stereo masks,
preflights spectral/median work and reconstructs the complete source extent.
The operator writes component WAVs and a bound measurement report; no style
format or historical reader was added. There are now 70 core units, 20 adapters
and 60 fixture programs.

Checked stable/development Win32 and stable Win64 pass independent DFT/inverse
checks, controlled separation/ownership/boundaries, the maintained core/operator
and saved-style blocks, and existing WAV/WFC learning fixtures. The controlled
tone/impulse mixture measures 40.60 dB harmonic and 19.34 dB percussive signal/error
on its interior; complete native recombination differs by at most 2.99e-8.
The original Pixel recording separates into two complete 1512000-frame stereo
clips with the same native error bound and encoded sum error below 3.06e-5.
Controlled and recorded component/audio bytes match across targets. Prior onset
reports remain unchanged when compared to the old executable on the same target.
Some Win64 report precision and consequent style identities differ from Win32,
as they did before extraction; no evidence-rounding policy was introduced.

Separated percussive onset/dynamics enters the current style format with derived
WAV identity, original-source hash and separation-report hash. The maintained
controlled second blend drives 64 cells / 160 notes / 705600 frames. Pixel's
derived style admits 154 onset cells, survives a second blend with the native
measured-dynamics source, and drives 64 cells / 305 notes / 610091 audio frames.
Saved recorded-style cross-loading and actual WFC PCM/audio/MIDI validation pass
on all three targets. Accompaniment pitches, voicings and one-cell gates remain
authored; spectral components do not establish instruments or isolated voices.

Evidence: `build/separation-{stable,trunk,win64}/`, especially `maintained-core.log`,
`maintained-style.log`, `learning-run.log`, `pixel-reconstruction.log`,
`recorded-style-check.log` and stable `replay.log`. See [separation](SEPARATION.md)
for policies, attribution and listening artifacts. The full ordinary workflow and
source ZIPs retain previous checkpoints; focused affected paths were verified.
No authored compiler warnings were found. Rejected operator options preserve all
three accepted artifacts. All jobs are terminal; retained vendor checkouts are
clean and the branch remains `hello-pythian`, without commits or pushes.
The complete original objective and provisional allocations stay open. Broader
recorded accuracy, polyphonic note/voice learning and delivery gates remain.

## Preceding local tonal-region checkpoint — 2026-09-15

Local tonal region admission now connects explicit key changes to regional WAV
evidence. `AdmitWaveKeyRegions` borrows a native clip/source grid, validates a
complete ordered partition, preflights aggregate analysis work and measures each
region independently. Results retain selected key/unknown, frame coordinates,
weights and full rankings. No FFT window includes neighboring region samples.
Native mappings support source offsets, changing clocks and arbitrary supported
PPQ; the CLI `admit-key-regions` exposes a declared constant clock and selected
cell starts. Existing context/profile formats retain admitted grids and report
hashes; no version, unit or fixture program was added.

The maintained local-key build block passes on checked FPC 3.2.2/3.3.1 Win32 and
3.2.2 Win64: controlled C-major/D-minor regions feed saved duration learning,
two-source blending, a second derivation and actual WFC voice output. Both audio
variants contain 32 performance spans / 45 notes / 197163 frames at 44100 Hz.
The key edit changes four accompaniment tones, retaining exact measured melody,
tempo, gates and held notes. An additional flute/bassoon blend follows the same
path. Pixel regional measurements retain unknown keys. Native replay checks bind
actual source/report bytes, saved models and every admitted grid cell.

Stable/development Win32 match 17 source/profile/style/output artifacts. Win64
matches all seven compared source/WAV/MIDI/preview artifacts; full-precision
regional weights differ by less than 7e-16 relative, with identical ranked
candidate identities. Report hashes and bound identities consequently differ;
the code does not quantize evidence to manufacture byte parity. Malformed regions,
wrong source hashes, absent local evidence and aggregate work overflow reject
without replacing accepted results. No authored compiler warnings were found.
Evidence: `build/local-key-{stable,trunk,win64}/`, especially `maintained-run.log`,
stable `replay.log`, `*-binding.log` and `rejection-status.log`.
Final stable `maintained-final.log` includes saved-profile replay in the maintained
block; `core-only/run.log` verifies the admission API without vendor search paths.

The prior turn was progress (public performance API and verified source delivery).
This turn advances local context/style integration; full ordinary build and
packaging retain preceding checkpoints. Source ZIPs do not include this new API.
All work stays on `hello-pythian`, without commits or vendor changes. Automatic
modulation/key admission, wider annotated recording accuracy and mixed-song
voice/timbre roles remain open under the original objective and allocations.
See [local region contracts and evidence](WAVE-CONTEXT-ADMISSION.md#explicit-local-key-regions).

## Preceding public performance API checkpoint — 2026-09-15

Saved-style performance coordination is now a reusable companion library API:
`pythian.wfc.performance` owns saved key/tempo/duration models, creates actual
named WFC sessions, supplies typed per-cell controls and captures detached spans
with native key/tempo timelines. Input styles, definitions, sessions and accepted
plans have independent documented lifetimes. Capture validates actual state paths,
emitted tokens and full finite context coverage. Failed capture preserves the
previous audible plan but does not roll back a successful symbolic session solve.

The duration voice demo now consumes that API. Pitch/duration locks on a single
span intersect into one mask, fixing the previous two-mask rejection. Existing
held and changing-context WAV/MIDI/preview/report bytes are retained. All three
auditions, including the one-span joint lock, match across checked stable and
development Win32 plus stable Win64 (24 comparisons). The existing native style
fixture checks released ownership, selective edits, infeasible-prefix recovery,
forged state/token rejection, insufficient coverage and a native 96-PPQ plan.
The complete maintained recorded workflow passes on stable Win32. Logs are under
`build/performance-api-{stable,trunk,win64}/`; final stable evidence includes
`final-api-run.log`, `final-replay.log` and `recorded-workflow.log`.

Fresh core and companion ZIPs include this API and the preceding waveform-morph
and explicit pitch-window additions. Extracted inventory hashes, every owned
unit and all five/seven delivered examples pass on stable Win32/Win64 respectively.
An external consumer using only extracted companion library paths also passes the
full public performance fixture against separately supplied saved test styles.
There are 68 core units, 20 adapters and still 59 fixture programs. See
[API ownership and controls](PERFORMANCE.md) and [delivery](PACKAGING.md).

The layered-style roadmap now distinguishes implemented weighted/repeated styles
and finite context changes from remaining semantic registration, arbitrary time
projections and broader learned roles. This adds no native format, historical
reader or compatibility commitment. Both packages are dependency subsets under
the single-current-format policy. All jobs are terminal; vendor checkouts are
clean, and no commit or push was made. The full ordinary workflow retains the
preceding morph checkpoint; focused checks and the maintained recorded workflow
cover this change. The original objective and provisional allocations remain
open without assigning percentage points to this supporting increment.

## Preceding explicit pitch-window checkpoint — 2026-09-15

Dense pitch tracks now accept explicit analysis width through
`TPitchTrack.Create(..., WindowFrames)`, independent of hop and estimator
thresholds. Zero retains the minimum default; positive widths must satisfy the
existing coverage and work bounds. Saved evidence retains the actual width in
its existing field. The native dense-pitch operator and `learn-duration` expose
`--window-frames`; duration onset articulation can be combined in either option
order. No format, estimator version, library unit or fixture program was added.

One declared 110 ms policy supplies correct stable notes with zero wrong stable
bins for all six recorded channel-0 references at 8000 and original 44100 Hz.
Bassoon C now has 30 correct / 26 unknown converted bins instead of the default's
28 correct / 3 wrong / 32 unknown. Longer complete windows reduce analyzed edge
coverage. A 60 ms note sequence retains 58 stable bins under the default and
none at 110 ms, demonstrating the resolution tradeoff. Bassoon channel 1 still
admits ten wrong bins at both rates; automatic harmonic disambiguation remains open.

The newly admitted bassoon style mixes 880-frame evidence with the flute's
294-frame evidence, then survives a second blend with bassoon (two sources,
depth three, five nodes, weights 2:1). Actual WFC passes generate note 48 with
five arranged notes / 19845 stereo frames. A `1:316` duration edit chooses flute
note 69, preserves key/tempo state and renders 21452 frames. Saved style identity
is `57c1d20f56403ee0e84c02c865205ec50c2fb2175b87e42e41dbca845dd6462e`.

Checked stable/development Win32 and stable Win64 pass native geometry/evidence
replay, twelve channel-0 recording references and actual saved-style output.
Five inspection/audio/MIDI/report artifacts match across these targets. Automatic
and explicit-minimum settings encode identical styles; malformed/wrong-mode
options and conflicting measurements of one source preserve accepted files.
The complete maintained recorded workflow passes on stable Win32, including
existing default paths, morph auditions, the mixed-window blend and voice edits.
Logs: `build/pitch-window-{stable,trunk,win64}/`, especially `replay.log`, stable
`options-status.log`, `recorded-workflow.log` and `workflow-status.log`.
Final native resolution checks are in each `final-core/run.log`. The ordinary
full workflow retains the preceding morph checkpoint; it was not repeated here.

All jobs are terminal; retained submodules are clean. The branch remains
`hello-pythian`, with no commits. Source ZIPs precede this extension. The original
objective and allocations remain open; broader recorded accuracy, mixed-song
voice roles/timbre inference and clean-checkout Linux CI are still unresolved.
See [recorded window evidence](PITCH.md#explicit-analysis-width-on-the-recorded-sources)
for counts, provenance and limits.

## Preceding waveform-morph checkpoint — 2026-09-15

The existing wavetable factory now owns two measured cycle recipes and a cloned
automation curve through `CreateMorph`. Each playback instance interpolates
their amplitudes with a shared phase and independent note-relative control
clock. Both banks retain their own pitch-dependent harmonic caps. Reset, note-off,
detached ownership, rejection preservation and source work admission retain the
existing renderer contracts. No library unit or persisted format was added.

The native source demo accepts `--morph-cycle` with two explicit WAV selections
and MIDI input. The changing-key/tempo WFC passage renders all 45 notes / 252000
stereo frames. Cached flute and bassoon cycles voice the recorded second-blend
passage: five notes / 23350 frames. A slower control changes waveform output
while preserving the input MIDI. Existing single-cycle and default source
auditions retain exact bytes. Cycles retain caller-selected phases/amplitudes;
the control trajectory is authored, not inferred or saved as PYS timbre evidence.

Checked source fixtures and both morph auditions pass on stable/development
Win32 and stable Win64. Both output WAVs match across these targets. Invalid
second-source cycle admission preserves the accepted WAV. Logs and native audio
metrics are under `build/morph-cycle-{stable,trunk,win64}/`; stable `replay.log`
records comparisons. See [waveform morphing](SOURCES.md#controlled-waveform-morphing)
for the public contract, commands and attribution. The complete maintained
stable Win32 workflow passes (`full-build.log`, `full-status.log`), including
the new morph command, saved styles and archive reconstruction. Its morph WAV
matches the focused audition exactly. The recorded workflow includes the new
two-source command; its changed audition was checked directly against cached
inputs, without repeating the full recorded-pitch evaluation. All jobs are
terminal. No owned compiler warnings were reported; upstream warnings remain.

The full objective and milestone allocations remain open. Broader recorded
accuracy, learned voice roles/timbre trajectories and clean-checkout Linux CI
remain unresolved. Source ZIPs below precede this API extension. Branch remains
`hello-pythian`; retained submodules are clean and no commits were made.

## Preceding source-delivery checkpoint — 2026-09-15

Current source delivery now includes source-clock duration normalization,
independent key/tempo contexts, measured-cycle recipes and saved onset
articulation. The core ZIP contains 68 units and five examples; the companion
ZIP adds 19 adapters, pinned WFC and two examples. Every content hash passes
extraction checks, every owned unit compiles, and all delivered examples run
on stable Win32 (core) and stable Win64 (companion). Extracted owned sources,
examples and package README matched that workspace checkpoint. Artifact paths and hashes are
recorded in [current source packages](PACKAGING.md#current-source-packages).

Existing fixtures also pass as external consumers of extracted sources:
development Win32 checks current core context, pitch and waveform APIs;
development Win64 checks saved style capabilities, second blends, source clocks,
provider scopes and generated voice gates. These focused checks use prior
generated test data outside the ZIP; delivered examples remain self-contained.
Logs are under `build/package-performance-{core,wfc}/`, with workspace equality
recorded in `build/package-performance-current.log`.

The local WSL execution probe failed with installation help and exit code 1;
Linux and clean-checkout CI remain unverified (`build/delivery-platform.log`).
The original goal and milestone allocations remain open. These package checks
refresh delivery evidence without awarding a new musical-capability percentage.
No new format reader, fixture program or library unit was added in this refresh.

## Preceding onset-articulation checkpoint — 2026-09-15

Saved duration styles now offer explicit source-onset articulation. The core
`RearticulatePitchSpans` partitions known pitched intervals at ordered attacks,
preserving pitch, extent and unknown/silent spans. The style adapter maps admitted
physical onsets through each source clock/offset, excluding out-of-scope cues
and rejecting collapsed PPQ attacks. `DurationArticulateOnsets` is retained as an
optional capability in the current PYST source mask. Raw measurements remain
unchanged; no additional format version or historical reader was introduced.

The native `learn-duration --monophonic --articulate-onsets` path saves this
policy and replays the resulting actual joint performance model. Weighted second
blends retain each source's policy and evidence. The independent-voice operator
also now supports its documented one-span request using order-one dependent
models; longer requests retain order two without training on score padding.

An independently authored four-second A4 source has one stable pitch run and
seven measured interior onsets under unchanged detector thresholds. The policy
turns one sustained span into eight pitched spans. The controlled native
auditions contain five versus forty arranged MIDI notes over the same 175113
stereo frames, retaining exact key/tempo states. The final observed 464-tick
duration is explicitly pinned in the repeated audition. A 2:1 second blend with
the changing harmonic source retains five ancestry nodes and produces 16 spans,
80 notes and 352248 frames. This is a controlled onset-ownership policy, not
automatic mixed-recording voice separation or general articulation accuracy.

Focused stable/development Win32 and stable Win64 checks pass. Seventeen
source/style/audio/MIDI/report files match between Win32 compilers. Native checks
cover actual model paths, gates and preview PCM, plus source-clock mapping on
both sides of a tempo change, physical offset, collapsed attack rejection and
missing duration evidence. Logs: `build/onset-duration-{stable,trunk,win64}/`,
especially `checks.log` and trunk `replay.log`. The complete maintained stable
Win32 workflow passes (`full-build.log`, `full-status.log`), including the new
controlled pair, second blend and preceding cycle/context/archive workflows.
A final guard tightening for negative duration windows was checked separately
on all three targets, including valid profile replay (`final-boundary-checks.log`).
The preceding recorded held-mode WAV/MIDI/preview/report retain exact bytes,
and a duration-only policy flag rejects in pitch-only mode without replacing
the accepted style (`build/onset-duration-trunk/held-replay.log`).

The original goal and milestone allocations remain active. Broader recorded
accuracy, mixed-source onset ownership/voice roles, whole-scope centered pitch,
remaining synthesis fundamentals and clean-checkout Linux CI remain open.
Source ZIPs at that checkpoint were earlier snapshots; the refresh above now
includes these changes. The branch remains `hello-pythian`.
All verification jobs are terminal. Changed files retain LF, no owned compiler
warnings were reported, and retained submodules are clean. No fixture program
or core unit was added; existing native fixtures and the maintained build were extended.

## Preceding measured-cycle checkpoint — 2026-09-15

The standalone wavetable unit now analyzes an explicitly selected PCM cycle into
detached signed sine/cosine coefficients and a separate measured DC value.
The existing harmonic-limited factory consumes this recipe after the source is
released. Bounds cover source/channel selection, 3..8192-frame periods, 1..128
harmonics strictly below cycle Nyquist, and the existing coefficient limit.
The result is published only after analysis succeeds, preserving an accepted
recipe even on a late coefficient failure.

`pythian.sources.demo --cycle` auditions the measured waveform over eight
authored notes, or applies it to strict native MIDI via `--midi`. The latter
keeps exact note timing/velocity and rejects omitted sub-frame/zero-length
notes; one explicit source binds every note, with no release spill. The tool
reports source/MIDI hashes and cycle coordinates. No waveform normalization,
cycle detection, new style format or historical reader is introduced.

Focused stable/development Win32 and stable Win64 checks pass; five controlled,
recorded and default WAVs match across these targets. The earlier default source
audition retains its bytes, and invalid cycle admission preserves its output.
The changing-key/tempo MIDI renders 45 notes / 252000 stereo frames at 48000 Hz.
The cached VSCO 2 CE flute cycle also voices the recorded second blend's five
notes in 23350 frames. Its low amplitude is retained, with peak about 0.01205.
The maintained recorded workflow passes on development Win32, including both
duration-edit auditions and the unchanged deferred bassoon-C accuracy case.
Evidence: `build/cycle-source-{stable,trunk,win64}/`, especially stable
`replay.log` and trunk `recorded-workflow.log` / `recorded-status.log`.
The existing source fixture and build/recorded workflows were extended; no new
fixture program or core unit was added. Full-suite/package refresh is not claimed.

This connects sample/synthesis fundamentals to the integrated style listening
path. Automatic cycle/timbre extraction, broader recorded musical accuracy and
voice roles, whole-scope centered pitch, remaining fundamentals and clean-checkout
Linux CI remain open. Keep the original milestone allocations and goal active.
All verification jobs are terminal; branch remains `hello-pythian`. Changed
files retain LF, no owned compiler warnings were reported, and retained
submodules are clean. Existing source ZIPs remain earlier snapshots.

## Preceding independent-key checkpoint — 2026-09-15

Duration-driven voices now also support an independent finite key-pass scope.
`--duration-key-cells` selects actual WFC key states on the saved context grid;
`--duration-key-lock CELL:ROOT:major|minor` selectively regenerates that pass
while preserving every accepted tempo/performance state. `KeyChangesFromTokens`
reconstructs a finite key timeline, and standalone `MapDiatonicPitch` maps
diatonic degree and octave between known major/natural-minor keys.

The operator samples key at each performance-span start. Authored bass/chord
guides use that key with fixed degree/octave; measured melody stays absolute.
Already sounding notes keep their pitch until their gate ends. This is an
explicit accompaniment policy, not inferred modulation or extracted voice roles.
The fixture's C-major/D-minor provider is caller-authored and labeled as such;
its derived style retains the original measured performance and ancestry.
No archive layout, version or compatibility path changed.

The controlled key edit changes 20 new accompaniment tones across 32 spans /
45 notes while preserving melody, tempo, velocities, gate endpoints and notes
already sounding across a key boundary. Focused stable/development Win32 and
stable Win64 checks pass. Eight Win32 WAV/MIDI/preview/report artifacts match
exactly. A combined key/tempo edit preserves accepted key/performance/voice
states through the tempo edit, and recorded held-mode audio/MIDI/preview bytes
retain their preceding values. Logs: `build/key-context-trunk/{checks,replay,workflow}.log`
and `build/key-context-win64/checks.log`. The complete maintained stable Win32
build passes (`build/key-context/full-stable.log`, `full-status.log`), including
the combined context edit and short-key-scope rejection preserving all four
accepted outputs. Its four combined-edit artifacts also match development
Win32. No owned compiler warnings were reported; source/docs retain LF and
retained submodules are clean. All verification jobs are terminal.

Whole-scope centered-pitch generation, broader recorded accuracy and voice-role
inference, remaining fundamentals and clean-checkout Linux CI remain open.
This advances the existing integrated milestone without assigning percentage
gains from fixture counts. Source ZIPs remain earlier snapshots without these
latest duration/context APIs. The branch remains `hello-pythian`.

## Preceding independent-tempo checkpoint — 2026-09-15

Duration-driven voices now support an independent finite tempo provider scope.
`--duration-tempo-cells` solves the saved tempo model at its own PPQ grid step,
separate from key's held state and the requested performance-span count.
`--duration-tempo-lock CELL:US` uses actual WFC selective regeneration of the
tempo pass while retaining accepted key/performance latent states and logical
voice frames. Duration and pitch edits retain all accepted tempo states.

The standalone `TTempoMap.Intervals` partitions exact tick ranges; the reusable
`TempoClockFromTokens` adapter validates finite provider coverage and permits an
endpoint inside the last used cell. `TimeWfcEnsembleFrame` produces detached
playback frames whose sounding continuations hold through tempo changes. The
actual five voice paths and full original note gates remain unchanged. Native
and WFC previews agree sample-for-sample, and native MIDI/stereo timing includes
changes inside notes. Original and playback frames have separate report fields.
No archive layout, version or source learning policy changed.

A saved derived style selects changing output context above the normalized
two-source second blend. Seed 731 produces 32 performance spans / 45 notes in
220500 frames. Pinning tempo cell 3 to 600000 us/quarter moves the change from tick
1920 to tick 720, inside a sounding span, and produces 231525 frames. All 45
MIDI gates retain their endpoints and pitches; all key/performance/voice states
remain exact. Three voices continue as holds at the internal change. The native
verifier independently matches each MIDI tempo event to a generated provider
cell and checks playback parts plus audible/unknown/rest intervals.

Focused FPC 3.2.2/3.3.1 Win32 and stable Win64 checks pass core partitions,
finite context reconstruction, detached playback ownership and saved output
validation. Eight Win32 WAV/MIDI/preview/report artifacts match exactly.
Insufficient tempo coverage rejects while preserving all four prior outputs.
The recorded flute/bassoon held-mode WAV/MIDI/preview bytes remain identical to
the preceding normalized workflow. Logs:
`build/duration-context-trunk/{checks,workflow,replay}.log` and
`build/duration-context-win64/checks.log`. The complete maintained FPC 3.2.2
Win32 build passes (`build/duration-context/full-stable.log`,
`full-status.log`), including earlier duration controls, corpus, archive and
timed reconstruction paths. No owned compiler warnings were reported. Changed
files retain LF, retained submodules are clean, and the branch remains
`hello-pythian`. All verification jobs are terminal.

At this checkpoint key remained held; the current checkpoint above adds its
explicit sounding-note and accompaniment policies. Whole-scope centered-pitch
generation, wider recorded accuracy, remaining fundamentals and clean-checkout
Linux CI also remain open. This advances the existing integrated milestone,
without treating fixture counts as progress percentages. Existing source ZIPs
remain earlier snapshots and do not contain these latest duration APIs.

## Preceding normalized-duration checkpoint — 2026-09-15

Dense duration styles now normalize measured physical intervals through each
source's complete clock to the shared PPQ timebase before weighted WFC learning.
The standalone `TPitchTrack.TimedSpans` retains pitch/silence/unknown identity,
intersects evidence with explicit source scope, rounds cumulative endpoints and
rejects intervals below PPQ resolution. Saved styles retain raw evidence and
replay the normalized model. Different source tempos, offsets and hop durations
no longer disable dense blending. No additional file-format version or historical
reader was added; development duration profiles require regeneration.

The changing harmonic source (offset 97, 500000→600000 us/quarter) now learns a
dense style, blends with the constant phrase and survives a second derivation.
The focused 32-span result generates 45 notes in 198450 stereo frames. Actual
three-provider/five-voice paths, MIDI gates and pitch/silence/unknown output pass.
Eight profile/audio/MIDI/report artifacts match stable and development Win32
exactly. Stable Win64 cross-loads the profiles and verifies their generated
output. Logs: `build/duration-clock-trunk/{checks,workflow,replay}.log` and
`build/duration-clock-win64/checks.log`.

The maintained recorded workflow also passes on development Win32 with cached,
hash-checked VSCO 2 CE sources. Flute/bassoon styles retain two source identities
and five ancestry nodes through a second blend. The observed 374-tick pin selects
bassoon MIDI 57 instead of flute MIDI 69 while preserving accepted key/tempo.
Three admitted performance spans produce five arranged notes in 21452 stereo
frames, including explicit unknown output intervals. Both source scopes now end
at their admitted two-cell context boundary; excluded raw tails remain in
evidence. The six independent recording checks still defer the same bassoon C
false harmonic. Log: `build/duration-clock-recorded/maintained-trunk.log`.

Core tests independently calculate rational boundaries across tempo changes,
physical offset and clipped scope, plus rejection/source preservation. The
changing-source archive check independently verifies every dense span's mapped
ticks. An additional development-Win32 check learns a normalized corpus from
80/160-frame hop measurements (`build/duration-clock-trunk/hop-check.log`).
The complete maintained stable Win32 build passes with regenerated duration
profiles, existing duration pins and independent tempo controls. Logs:
`build/duration-clock/full-stable.log` and `full-status.log`. The maintained
local second blend produces 45 notes / 198450 frames; selecting the independent
faster tempo produces 99225 frames with identical performance and voice states.
No owned compiler warnings were reported. Source/script LF checks pass and the
retained submodules are clean. Existing source ZIPs remain preceding-checkpoint
snapshots; they have not been regenerated for this API change.

Remaining integration includes changing output context in the duration-driven
voice operator (currently explicit single-valued held key/tempo), whole-scope
centered-pitch generation from short gapped phrases, and broader measured
recording accuracy. Fundamentals and clean-checkout/Linux CI remain part of the
original objective. This advances the existing major milestone without assigning
progress from fixture counts.

## Preceding local source-grid checkpoint — 2026-09-15

[Local source clocks](WAVE-STYLE.md#local-source-clocks-through-voice-generation)
now reach WAV rhythm/intensity and centered pitch learning, saved styles and
actual generated voice timing. The new standalone `TMusicGridFrames` maps a full
tempo history and physical source offset to immutable finite cell boundaries.
Constant-clock rhythm/pitch APIs delegate to the same implementation. Source
clock arrays survive detached copies and weighted repeated blends; construction
and loading bind every source cell to its saved context tempo and origin.

The maintained two-source second blend drives 32 attacks / 160 notes in 776097
stereo frames. Its native verifier requires actual output tempo changes and
checks model binding, voice realization and WAV/MIDI output. Pixel Sprinter adds
128 onsets on its tracked 158-cell grid; the recorded/controlled second blend
drives 47 attacks / 235 notes through the same changing output clock. Stable
Win32 renders/verifies that recording path, and development Win32 cross-loads
its saved style and passes the output checks. Recorded voice pitches remain
authored. Logs: `build/local-style-stable/recorded-workflow.log` and
`build/local-style-trunk/recorded-replay.log`.

An independent harmonic fixture at source offset 97 changes tempo after cell 15.
All 30 known pitches and two silent cells survive measurement and style replay;
a mismatched clock rejects without mutating accepted source evidence. Independent
fragment generation produces 16 attacks / 80 notes in 846720 frames, selecting
the 600000-us region. The 64-cell whole-scope requests, including coupled pitch,
fail for this fixture/seed. Successful fragment generation is not claimed as a
whole-source progression. Dense duration admission still explicitly requires a
constant frame-zero source clock and preserves a prior style when rejected.

The current PYST payload includes source frame offset, finite cell count and
tempo changes. Superseded development styles require regeneration; no historical
reader, migration chain or additional format branch was introduced. The PTC/PCP
layout from the preceding checkpoint is unchanged. Current counts are 68 core
units, 19 adapters and 59 fixture programs; existing fixtures were extended.

The exact maintained new workflow and native mapped checks pass on development
Win32. Both Win64 compilers pass changing pitch measurement, mapped rhythm and
style checks, and loading the current Win32 pitch style. Logs:
`build/local-style-trunk/` and `build/local-grid-{stable,trunk}-win64/`.
The complete maintained stable Win32 build passes with current styles regenerated
(`build/local-style-full-stable.log`, `build/local-style-full-stable-status.log`).
Seventeen source/context/style/audio/MIDI/report artifacts match development
Win32 byte-for-byte (`build/local-style-replay.log`). No owned compiler warnings;
retained submodules remain unchanged. Refreshed standalone and WFC companion
packages verify all 77/196 content hashes, compile all 68/87 owned units and run
all five/seven extracted consumer examples. Their shipped owned source and
package README match the worktree (`build/local-grid-package-current.log`).
See [current packages](PACKAGING.md#current-source-packages).

The next integration is normalization of dense durations on changing clocks,
while preserving the original requirements for broader recorded pitch/voice
accuracy, synthesis fundamentals and clean-checkout CI. The full objective and
integrated milestone remain open; no percentage is inferred from fixture counts.

## Preceding tracked-context checkpoint — 2026-09-15

[Changing-tempo pulse admission](WAVE-CONTEXT-ADMISSION.md#changing-tempo-pulse-ranges)
now connects the existing local tracker to typed context grids and actual saved
WFC key/tempo models. The caller selects a contiguous range and declares quarter
intervals. Core admission retains the exact source origin, rounds cumulative
microseconds to avoid interval drift, reports every boundary error and rejects
gaps, restarts, uncertain joins and invalid scopes without replacing prior results.

`pythian.context.track` provides native inspection, admission and saved-model
audition. The controlled 120-to-100 BPM WAV supplies 24 tracked pulses / 23
complete intervals / 46 context cells. After source measurements are released,
the saved models drive 23 authored cue tones in 555660 stereo frames at 44100 Hz.
The native verifier replays full source measurement/track reports and exact
source/report/profile bindings, then checks every audible cue and silent gap.
This is an audible timing proof, not learned voice pitch or musical arrangement.

The cached, previously attributed Pixel Sprinter recording also passes the
complete tracked-context path on development Win32. Its selected range 0..79
contains 80 pulses, no flagged grid joins and 158 context cells, from source
frames 18855 to 1507404. Saved-model audition has 79 cues in 1488549 stereo
frames. Key remains unknown. Full native source/report/profile and audible/silent
gate replay passes; this does not establish annotated beat or downbeat accuracy.
Evidence: `build/track-admission-trunk/pixel-workflow.log`, `pixel.{json,pcp,wav}`.
Attempting fixed-clock style learning from this relative context rejects and
preserves a valid baseline style (`style-rejection.log`).

`TContextEvidence.SourceFrameOffset` now represents the source frame at clock
tick zero. It survives copies and current context serialization; absolute clocks
use zero. The current PTC layout is consolidated in place, requiring regeneration
of earlier PTC/PCP and containing PYS development files. No historical readers
or parallel format versions were added. Fixed-clock style admission explicitly
rejects nonzero offsets rather than silently treating an interior pulse as frame
zero. The earlier constant-tempo requirement remains in force.

Focused FPC 3.3.1 Win32 checks pass core admission, archive and profile contracts,
actual tracked WAV admission, saved-model audition and native output verification.
Both checked Win64 compilers pass the core track/admission fixture. Invalid pulse
ranges and a wrong source hash preserve accepted profile/report files. Logs:
`build/track-admission-trunk/` and `build/track-core-{stable,trunk}-win64/`.
The complete maintained FPC 3.2.2 Win32 build passes, including regenerated
current-format context/styles, the new tracked workflow and the preceding
synthesis, MIDI, archive and WFC paths (`build/track-full-stable.log`). The new
controlled report/profile/WAV match development Win32 byte-for-byte
(`build/track-admission-replay.log`). No owned compiler warnings; retained
submodules remain unchanged. Earlier source packages remain snapshots of their
documented checkpoints, not current-format delivery evidence. Fixture-program
count remains 59; existing relevant fixtures were extended.

Local clock admission into higher rhythm/pitch styles and duration normalization
remain open, alongside recorded pitch/voice accuracy, synthesis fundamentals and
clean-checkout CI. This advances the measured-clock outcome within the original
integrated milestone; no percentage is awarded from additional checks.

## Preceding phrase-performance checkpoint — 2026-09-15

The maintained measured-phrase workflow now learns dense pitch/duration styles
from the original and shifted WAV, blends them with 2:1 weights, reuses that
derived style in another blend, and generates through held key/tempo/performance
providers followed by five dependent WFC voice passes. The 32-span result has
50 notes and 214803 stereo/preview frames. Selecting the same source's measured
240-BPM alternative in a further blend produces 107401 frames while preserving
the key provider, performance tokens and all five logical voice paths. Both
outputs pass exact MIDI gate and native audible/unknown/silence checks.

`SummarizePitchCells` exposes admitted, silent, uncertain and unmeasured counts
plus observed known runs. Style inspection reports this per source. Fresh
inspection corrects the earlier informal count: the saved shifted phrase has
11 admitted cells, four uncertain cells, no silent cells, five known runs and
a longest run of five cells. Unknown pitch is never reclassified as a rest.
A rejected 64-cell coupled request now points to the inspection and existing
dense duration workflow, and preserves accepted WAV output. Observed run length
is not a guarantee or upper bound on generated length.

Checked FPC 3.2.2 and 3.3.1 Win32 runs pass the exact new maintained build block,
the pitch summary fixtures and source-phase checks. Sixteen saved style/context/
audio/MIDI/report artifacts match byte-for-byte. The generalized independent
tempo comparison also passes the earlier 3:2 control pair. Evidence is under
`build/phrase-performance-{current,trunk}/` (`workflow.log`, `summary-checks.log`;
stable `replay.log`, `pitch-inspect.json`, `rejection.log`). Build script syntax
passes. These are focused current checks, not a new complete build or package
refresh; the packages below represent the preceding source-phase snapshot.

No format revision, duplicate model or compatibility reader was added. The
dense learner still uses its explicit whole-source hop clock. Bass/chord pitches,
voice roles and timbre remain authored; this does not establish polyphonic
transcription or resolve the recorded bassoon false-harmonic admission. Local
changing-clock admission, broader recorded voice accuracy, remaining synthesis
fundamentals and clean-checkout CI keep the full objective open. This advances
the existing integrated milestone without awarding points from fixture counts.

## Preceding source-phase checkpoint — 2026-09-15

[Selected source pulse phase](WAVE-CONTEXT-ADMISSION.md#selected-beat-phase-and-source-scope)
now reaches saved context, rhythm admission, pitch-cell measurement and repeated
style blending. `pythian.beat.wave` extracts the existing beat operator frontend
into reusable native code. `AdmitBeatContext` quantizes an explicitly selected
period/phase to the integer tempo and PPQ clock, reports signed errors and retains
the source origin in the existing context grid start tick. No downbeat is inferred.

Rhythm and pitch-cell APIs accept an optional source start tick, default zero.
Leading observations remain outside scope, and only exact complete cells fit.
Current style evidence binds its source start tick to the tempo provider and
preserves independent origins through weighted second derivation. The PCP schema
is unchanged. PYST now contains the source start tick; earlier development styles
must be regenerated, with no historical reader or parallel format branch. Dense
duration evidence continues using its explicitly separate whole-source hop clock.

The controlled phrase shifted by 1000 source frames selects 120 BPM and tick 123
(frame 1025, phase quantization error -0.487 frames). Seven onsets are admitted
where the frame-zero control admits none at the same tolerance. Shifted pitch
windows recover the known C/E/G/high-C notes. Two independently aligned sources
survive a weighted second derivation and drive 31 onset/intensity-controlled
attacks / 155 notes in 710892 stereo frames through actual WFC passes.

Pixel Sprinter's explicitly selected rank-one candidate is 139.75 BPM,
429338 us/quarter, tick 411 and floor/ceiling source frames 16212/16213.
Its phase/period quantization errors are -1.735 / -0.004576 frames. Its 158 cells
admit 89 onsets. A recorded/controlled second blend drives 39 attacks / 195 notes,
605881 preview frames and 611173 stereo frames. The 70-BPM alternative and
uncalibrated support remain visible; no annotated beat/downbeat accuracy is claimed.

Focused stable/development Win32 checks pass core scope boundaries, real source/
report replay, aligned pitch cells, saved style lineage and actual audio/MIDI
output. The exact new maintained workflow passes on both Win32 compilers. Eighteen
source/profile/style/audio/MIDI/report artifacts match byte-for-byte
(`build/phase-replay.log`). Stable
Win32 also passes the recorded workflow and rejected-rank/source-hash preservation.
Both Win64 compilers pass native phase/scope checks. The original beat operator's
controlled report bytes are unchanged after frontend extraction. Refreshed
67-core / 19-adapter packages pass all content hashes and extracted consumers;
their shipped source matches the worktree. Logs: `build/phase-admission-{stable,trunk}/`,
`build/phase-core-{stable,trunk}-win64/`, `build/package-phase-{core,wfc}.log` and
`build/phase-package-current.log`. Fixture-program count remains 59.

A 64-cell coupled-pitch request from the short gapped phrase fails. Successful
audible examples use learned onset/intensity with authored pitches; shifted pitch
measurement alone is not claimed as a successful long coupled-pitch path. Source
phase integration advances the existing major milestone, while local changing
tempo admission, downbeat/meter, broader recorded voice/pitch accuracy, remaining
synthesis fundamentals and clean-checkout CI still keep the full goal open.
The complete maintained stable build now passes, including regenerated current
styles and the existing synthesis, MIDI, source, archive and WFC workflows.
Evidence: `build/phase-full-stable.log` and `build/phase-full-stable-status.log`.
No owned compiler warnings; both retained submodules remain unchanged. Linux CI
execution is still unverified. Continue with admission of changing musical timing
and broader recorded voice behavior within the original outcome milestones.

## Preceding extensible-input checkpoint — 2026-09-15

[Extensible WAV input](WAVE-READING.md#extensible-pcm-and-float-input) now joins
the shared bounded reader, whole-clip loading, spectral analysis and actual WFC
learning/reconstruction. PCM8/16/24/32 accepts explicit valid-bit precision;
float32 retains finite headroom. Complete subtype GUIDs, extension extents and
supported mono/stereo masks are checked. Unused PCM bits and nonfinite floats
reject at read time without publishing partial blocks. No native style/archive
revision, alternate reader or external decoding dependency was introduced.

Checked FPC 3.2.2 and 3.3.1 runs pass on i386-win32 and x86_64-win64. Native
fixtures verify signed/unsigned precision boundaries, stereo ordering, short
reads, seeks, RIFF/RF64 and data-before-format. Invalid headers, subtypes, speaker
layouts, precision, sample padding and float encodings reject. Core golden checks
and existing bounded-analysis checks also pass; no owned compiler warnings.

Four extensible encodings of the authored 67032-frame stereo recording have exact
measured feature parity with ordinary PCM16 on every target. The real learner
produces the same 16-token / 22-state model from 66 observations; the WFC consumer
reconstructs 64 grains with identical WAV bytes. Bounded PCM16 transcoding also
reproduces every original byte. These comparisons are within each compiler/target,
not a universal cross-target DSP identity claim. Source-file hashes correctly
differ with the encoding. Evidence: `build/extensible-{stable,trunk}-{win32,win64}/`,
including `workflow.log`, `analysis-*.log`, native build/run and consumer logs.

The exact added maintained build block passes on stable Win32 using the full
synthesis smoke source (348 observations / 36 states); complete script syntax
also passes. Refreshed [core/WFC packages](PACKAGING.md#current-source-packages)
include the input extension. Every owned unit and packaged consumer passes,
and all shipped source/documentation bytes match the worktree. The extracted
WFC consumer reproduces all four extensible reconstructions. Evidence:
`build/package-extensible-{core,wfc}.log`, `build/extensible-package-check.log`,
and `build/extensible-stable-win32/maintained-block.log`.

The preceding delivery work verified the complete maintained build after the
shared sample-time fix (`build/current-full-fixed-status.log`). Its 66-core /
19-adapter packages pass staged hash checks, extracted-source builds and native
consumers; the same WFC package also passes both development Windows targets.
An 80 ms synthesis release now occupies 3528 frames at 44100 Hz on all checked
targets. Some DSP samples still differ by one PCM16 step across compilers;
saved event models load and reconstruct against their exact source bindings.
The [native CI workflow](../.github/workflows/native.yml) is configured and locally
parsed; Linux execution and a first remote clean-checkout run remain unverified.

This advances input interoperability and delivery within the existing substantial
outcome allocations. It does not establish musical inference from mixed songs.
Next, integrate existing measured beat phase/local timing with saved context and
style admission, then evaluate broader recorded pitch/voice behavior. Reuse
`pythian.beat` / `pythian.beat.track`; their estimation primitives already exist.
Local key uncertainty, harmonic/decay ambiguity, note boundaries, voice roles,
remaining synthesis fundamentals and clean-checkout delivery keep the goal open.
Counts remain 66 core units / 19 adapters / 59 fixture programs. Do not award
the full milestone or a percentage increase from these counts alone.

## Preceding measured-tempo checkpoint — 2026-09-15

[Measured global tempo candidates](WAVE-CONTEXT-ADMISSION.md#measured-tempo-candidates)
now feed the current saved-context/style workflow. The new standalone
`pythian.tempo` unit ranks bounded normalized spectral-flux periodicity with
explicit settings, metrical alternatives and absent-evidence statuses. It reuses
native analysis and has no WFC dependency. The operator's `inspect-tempo` exposes
candidates; `admit-tempo` recomputes reviewed-source evidence and admits a selected
rank into the existing PCP contract. Key selection stays explicit, including
unknown. Report hashes remain bound through current PYS styles and repeated
blends; no format revision or historical reader is introduced.

The authored 120-BPM source measures 119.8352 BPM (rank 0, 500688 us/quarter).
Pixel Sprinter's documented 140-BPM pulse appears at 139.9098 BPM (rank 1,
428848 us/quarter); its strongest candidate is the 69.9786-BPM alternative.
This supports explicit musical pulse selection, not automatic correct-rank
admission. Existing exact source scope admits 15 and 159 complete cells rather
than the declared-clock examples' 16 and 160. Frame zero remains unverified phase.

A saved two-source style selects the controlled key and measured Pixel tempo,
then passes a second 2:1 blend with depth 3 / five nodes. Actual WFC provider and
voice passes produce 53 onset-driven attacks / 265 notes, 605190 preview frames
and 610482 stereo frames with authored release. Measured source onsets and tempo
control generation; this example does not claim measured pitch or voice roles.
The controlled offline block independently renders 31 attacks / 155 notes and
706570 frames from its measured style.

That direct controlled style exposed a real source-boundary incompatibility:
its 15-cell alternating onset sequence cannot satisfy the operator's fixed
64-cell whole-path request. `--style-extent whole|prefix|fragment` now exposes
actual WFC provider extent selection. The offline example explicitly selects
prefix semantics; no observations are added, and defaults remain unchanged.
Native output checks validate each provider path against the requested extent.
The five dependent voice-model paths still require whole-sequence validation.

Checked FPC 3.2.2 and 3.3.1 i386-win32 runs pass exact synthetic pulse/alternative
checks, silence/lone-onset/constant-strength rejection, insufficient duration,
invalid/nonfinite geometry and bounded-work failure. The core fixture compiles
with only native source paths. Profile checks hash actual WAV/report bytes,
remeasure every tempo candidate, verify the admitted clock and generate from
the retained WFC models. Both complete recorded second-blend workflows and the
exact maintained offline command block pass. Twenty-three context/style/report/
audio/MIDI artifacts match across compilers. Three invalid tempo admissions and
three invalid extent requests per compiler preserve accepted files. Declared
context JSON/PCP and eight existing coupled/duration voice artifacts retain their
previous bytes. No owned compiler warnings; build-script syntax and executed
block checked. Counts: 66 core units / 19 adapters / 59 fixture programs.

Evidence: `build/tempo-admission-{stable,trunk}/workflow.log`, `core-final.log`,
`maintained-block.log`, `compatibility.log`, `rejection.log`, `extent-rejection.log`,
compiler logs and `build/tempo-admission-replay.log`. No full-suite, package, CI or
additional-target claim. Pulse scores are uncalibrated; two source matches do
not establish broad tempo accuracy. Beat phase, meter/downbeats, changing tempo,
local key uncertainty, broader recorded pitch/voice admission and remaining
fundamentals/delivery keep the full goal open. Continue these substantial outcomes
within the existing milestone instead of awarding completion from feature counts.

## Preceding duration-voice checkpoint — 2026-09-15

[Duration-driven dependent voices](INDEPENDENT-VOICES.md#measured-duration-driving-dependent-voices)
now connect saved measured performance to the existing five-pass WFC voice stack.
Three actual provider passes use independent 1/1/N key/tempo/performance scopes;
observed pitch/kind/duration tokens drive melody pitch and all bass/chord/melody
gate endpoints. Selective duration or pitch edits preserve accepted key/tempo
states before rebuilding dependent models. Bass/chord pitches, intensity, timbre
and meter remain authored. Sources remain declared monophonic recordings.

The reusable `ProjectRetimedWfcNotes` adapter maps exact logical cell boundaries
to cumulative native note timing while retaining tempo values and voice identity.
WFC's logical score has trailing rests to satisfy its complete-measure contract;
training selections and realized output exclude that padding. Native MIDI and
audio end at the requested measured endpoint. Unknown/silence spans remain
distinct evidence and become exact output rests. Preview PCM matches the actual
WFC renderer with variable frame lengths. Duration-mode MIDI has independent
native gate/tempo/extent checks, not byte parity with the logical padded score.
The current PYS format is unchanged; no historical reader or new format branch.

FPC 3.2.2 and 3.3.1 i386-win32 pass the focused checked workflow. The acoustic
second blend renders three spans, five notes and 26919 stereo frames. Its observed
`1:39` duration edit selects melody 57 instead of 69, producing 24255 frames;
`--pitch-lock 1:57` selects the same observed performance with identical audio/MIDI.
The controlled eight-span second blend produces ten notes and 42813 frames;
750000-us tempo preserves all performance/voice tokens and produces 64220 frames.
Native assertions verify original provider hashes, actual paths through all five
voice models, every exported tone/gate, saved PPQ/tempo, independently calculated
span endpoints and audible versus exactly silent intervals. These checks do not
claim acoustic pitch separation of every tone in a synthesized chord.

Twenty-four WAV/report/MIDI/preview artifacts match across compilers. All four
maintained fixed-duration coupled-voice artifacts retain their previous bytes.
Eight rejected requests per compiler (bounds, unavailable duration capability,
missing style, unobserved/conflicting controls and incompatible/duplicate options)
preserve all four accepted outputs. Adapter fixtures also cover arbitrary native
endpoints, tempo changes and rejection of unaligned/cropped sounding notes.
Evidence: `build/duration-voices-{stable,trunk}/workflow.log`, `rejection.log`,
`pitch-control.log`, compiler logs and `build/duration-voices-replay.log`.
Both maintained PowerShell scripts parse; their new native command paths were
exercised in the focused run. No full-build, package, CI or additional target claim.
Core/adapters/fixture-program counts remain 65 / 19 / 59.

The ordinary offline build includes controlled duration voices and independent
tempo selection. The optional recorded workflow includes acoustic duration voices
and a selective edit. This closes duration-driven accompaniment under held
context within the existing integrated milestone. Timed changing context,
recorded harmonic/decay ambiguity, physical note boundaries, same-pitch
rearticulation, mixed-song voice roles, measured source clocks and broader
fundamentals/delivery still prevent overall completion. Keep the provisional
percentage assessment tied to those outcomes rather than individual options.

## Preceding held-context checkpoint — 2026-09-15

[Independent layer scopes](LAYERS.md#per-layer-scopes) now expose actual WFC
pass layouts through optional per-layer counts and extents. Empty scope arrays
retain the shared defaults. Sessions own copied scopes, apply masks within each
pass's bounds and validate captured paths against their own prefix/whole/fragment/
suffix/wrap contract. Work budgets use each model's actual state/cell product.
Existing positional projections require equal counts; unequal scopes reject
until an explicit time mapping is provided.

The duration operator adds explicit `--context hold`: one actual prefix state
from each single-valued saved key/tempo model holds across the independently sized
performance pass. No saved models or observations change. Unknown key remains
unknown; changing/alternative values reject rather than flattening. Each report
retains provider extent/path and the output hold endpoint. The default remains
sequence context, and no new archive or historical format reader was introduced.

The recorded second blend now demonstrates 1/1/3-cell key/tempo/performance passes.
Flute-derived output contains MIDI 69 in 26919 stereo frames; the observed `1:39`
edit selects MIDI 57 in 24255 frames and preserves accepted context states. The
controlled eight-span held example retains four pitches while independent tempo
selection scales 44100 frames to 66150. Every generated pitch, unknown/silent frame,
source/model binding and exact clock boundary passes native output checks.

Correction to the preceding diagnosis: the prior binary also renders three spans
with prefix semantics and produces identical constant-context audio. The earlier
failure was WFC's interior-fragment boundary restriction, not a hard limit imposed
by two source context cells. The new capability is independent context scope and
an explicit output hold. Original source scope is not inferred or extended.

FPC 3.2.2 and 3.3.1 i386-win32 pass independent 1/3/6-cell prefix/whole/wrapped
layouts, scope ownership, selective masks, unknown context and changing-tempo
rejection. Nine affected consumers compile without owned warnings. Existing layer
and context-profile fixtures pass; default duration audio and all four maintained
coupled-voice artifacts retain their bytes. An exploratory unpinned voice request
also fails with the prior binary; the maintained pinned case passes on both.
Invalid modes, duplicate controls and unsupported performance extents preserve
accepted WAV/report files. Nineteen current style/report/WAV/MIDI artifacts match
across compilers. Evidence: `build/held-context-{stable,trunk}/workflow.log`,
`regression.log` and `build/held-context-replay.log`. Core/adapters/fixture-program
counts remain 65 / 19 / 59; no full-suite, package or additional target claim.

Constant held context is supported. Timed changing context and explicit mappings
between different musical resolutions remain open, as does duration-driven
accompaniment. Continue that integrated milestone; recorded harmonic/decay
ambiguity, physical note boundaries, rearticulation, polyphonic roles, measured
source clocks and broader fundamentals/delivery still prevent overall completion.

## Preceding recorded-instrument checkpoint — 2026-09-15

[Recorded instrument evidence](PITCH.md#recorded-instrument-evidence) now covers
six pinned CC0 VSCO 2 CE acoustic samples with independent upstream SFZ MIDI
references. Native checks compare original 44100-Hz audio and explicitly converted
8000-Hz input without changing admission thresholds. Five samples admit only their
reference pitch, with incomplete measured coverage. Bassoon C admits a false MIDI
67 run instead of 48 in both original and converted audio. That case remains
deferred and excluded from the validated blend; it is not counted as a passed
accuracy case. Flute A loses three admitted bins after conversion, also recorded.

Two admitted recordings pass saved duration learning and a second blend retaining
2:1 source weights, depth 3 and five ancestry nodes. Native generation supports
explicit span count and WFC prefix/fragment semantics. A two-span prefix renders
the flute-derived MIDI 69; the observed `1:39` duration edit selects bassoon-derived
MIDI 57 while preserving accepted key/tempo states. Both are 17640 stereo frames,
with independently checked audible pitch, exact clocks and silent unknown bins.
Timbre remains authored. Dense `inspect-runs` also writes diagnostic evidence when
no pitch is admitted, without constructing or claiming a model.

The optional [recorded workflow](../tools/recorded-pitch.ps1) pins source hashes,
retains attribution and per-source PASS/DEFERRED logs, and keeps acquisition out
of the ordinary offline build. FPC 3.2.2 and 3.3.1 i386-win32 reproduce all 27
current recorded WAV/context/style/report/output artifacts exactly. Changed-path
regressions pass core pitch, dense learning, default eight-span audio and existing
duration edits, no-pitch inspection, invalid option rejection and output preservation.
No owned compiler warnings were found. Evidence: `build/recorded-pitch-{stable,trunk}.log`,
`build/recorded-pitch-replay.log` and `build/recorded-pitch-{compiler}-i386-win32/regression.log`.
Core/adapters and maintained fixture-program counts remain 65 / 19 / 59.

This is recorded isolated-note validation, not general song transcription or the
complete integrated milestone. The short recordings exposed an architectural
question: key/tempo grids have two cells, while dense performance has three spans;
an interior fragment cannot start in WFC beginning-history states. The subsequent
checkpoint above corrects the initial two-cell-limit diagnosis and adds explicit
independent held context. Duration-driven accompaniment and temporal mappings
remain part of the existing integrated milestone.
Harmonic/decay ambiguity, same-pitch rearticulation, physical note boundaries,
polyphonic roles, source-clock admission and broader fundamentals/delivery remain open.
No format variant, compatibility reader, dependency change or release claim was added.

## Preceding saved-duration checkpoint — 2026-09-15

[Saved duration styles](PITCH.md#saved-duration-styles) now retain dense
measurements through source profiles, weighted blends and second derivations.
Detached evidence reconstruction and cell admission share native pitch-diagnostic
validation, including tuning and silence/energy agreement. The current PYST format
contains optional dense evidence and a canonical duration model; older development
files need regeneration. No historical reader or format variant was added.

Duration follows pitch-source weights and retains observed pitch/kind/duration
relationships. Every positive pitch contributor must have dense evidence with
matching hop duration and source tempo. Otherwise duration is unavailable while
other supported style dimensions remain usable. A selected output tempo can
differ independently from the source reference tempo. Cumulative hop boundaries
map to PPQ through the existing exact clock rather than rounding each duration.

The duration operator now consumes saved key, tempo and performance models in
three named actual WFC passes. An observed duration pin regenerates only the
performance pass and preserves accepted key/tempo states. Two controlled WAVs
pass a second derivation with weights 2:1 and five ancestry nodes. That profile
renders four notes into 44100 stereo frames; independent 750000-us tempo selection
retains performance states and yields 66150 frames. The 40-hop duration pin changes
the performance to three notes in 93528 frames while preserving base context.

FPC 3.2.2 and 3.3.1 i386-win32 pass current archive/model replay, forged evidence
and capability failures, exact cumulative PPQ boundaries, three actual provider
paths, every audible pitch and every silent/unknown frame. Unobserved pins and
unavailable duration models preserve prior output files. The existing cell,
standalone duration, independent-dimension and coupled-style workflows also pass.
Fifty-five current profile/report/audio/MIDI artifacts match across compilers;
no owned compiler warnings remain. Evidence:
`build/duration-style-verified-{stable,trunk}/`, `workflow.log`, `core.log`,
`pitch-regression.log`, `final-edit.log`, `rejection.log` and
`build/duration-style-replay.log`. This remains focused validation at 65 core /
19 adapters and 59 fixture programs, not a new full-suite/package checkpoint.

Saved-style duration integration is complete for this monophonic interval path.
The five-pass cell voice operator still needs duration-driven accompaniment.
Recorded-instrument validation, same-pitch rearticulation without an admitted gap,
physical note boundaries, polyphonic roles and measured source clocks remain
open. Preserve those requirements and the broader milestone scope.

## Preceding dense-duration checkpoint — 2026-09-15

[Dense monophonic duration learning](PITCH.md#dense-measurements-and-learned-duration)
now carries overlapping source measurements through stable note spans, weighted
actual WFC learning, saved-model generation and native gated audio. The core track
is immutable and independent of WFC. It retains measured silence and unresolved
intervals as different kinds; short pitch runs remain unknown. Source-window and
frame coordinates make its boundary resolution inspectable. The companion learns
complete independent recording samples with explicit unknown tokens and requires
an exact shared hop timebase. Existing plain/paired pitch learning remains intact.

The five-second native performance has six notes with varied durations and a
repeated pitch separated by a measured gap. All six notes match independent pitch
references; maximum boundary error is 107 frames at 8000 Hz (13.375 ms). Its saved
model contains 23 pitch/silence/unknown spans. Eight generated spans produce three
audible notes of 400, 790 and 400 ms. Doubling the duration quantum preserves every
solved state and pitch while doubling output from 77175 to 154350 stereo frames.
Native articulation prevents release tails from filling silent/unknown spans.

FPC 3.2.2 and 3.3.1 i386-win32 pass the focused duration workflow, weighted
two-source corpus comparison, timebase rejection, every audible pitch and every
silent/unknown output frame. Invalid channel and incompatible model requests
preserve accepted files. Existing cell-pitch audio and coupled repeated-style
generation also pass. Sixteen source/evidence/model/audio artifacts match across
compilers. Evidence: `build/pitch-runs-{stable,trunk}/`, `core.log`, `duration.log`,
`cell-regression.log`, `style-regression.log`, `rejection.log` and
`build/pitch-runs-replay.log`. This is focused validation at 65 core / 19 adapters;
no additional fixture program, full-suite, package or target claim is made.

This duration model is a standalone measured interval contract. The existing
saved layered styles still use their documented cell gates. Next integrate
measured duration evidence and explicit unknown handling into those profiles and
dependent voice passes, and validate against recorded monophonic instruments.
Same-pitch rearticulation without an admitted gap, physical note-on/off accuracy,
polyphonic roles and measured source clocks remain open. Keep the provisional
milestone allocation unchanged until the complete integrated outcome is verified.

## Preceding coupled-pitch checkpoint — 2026-09-15

[Observed pitch/onset runs](PITCH.md#saved-pitch-styles-and-layer-control) now
survive learning, save/reload and repeated weighted blends. The same actual WFC
learner handles plain and paired pitch runs, splitting at unknown pitch cells
and recording boundaries. Joint capability requires identical normalized source
vectors for rhythm and pitch; independently selected dimensions do not claim
observed cross-source pairs. Optional intensity remains part of the aligned
evidence. This extends the current PYST format with an optional model field;
regenerate superseded development files instead of retaining historical readers.

Explicit coupled generation inserts a named pitch/rhythm provider after key and
tempo and projects its observed pairs into onset, optional intensity and pitch
consumers. Edits regenerate that closure and retain exact key/tempo state.
Independent mode remains available. A downstream pitch pin initially exhausted
the pass-search budget on a second blend. Back-projecting the same pin onto
observed provider alternatives resolves that case without changing budgets or
removing consumer constraints.

Both checked compilers pass focused current-format learning, repeated blending,
independent and coupled generation, selective edits and actual WAV/MIDI binding.
The controlled coupled baseline, edit and second blend each render 24 attacks /
120 notes into 705600 stereo frames. Native fixtures compare paired learning
against independently specified weighted samples; source pitch labels, unknown
gaps, every generated pair and every melody attack are checked. Standalone pitch
learning still passes all 32 audible pitch measurements. Unavailable coupling
rejects while preserving all four existing output files. Evidence:
`build/pitch-rhythm-verified-{stable,trunk}/`; `coupled.log` and `reblend.log`
record the final solver behavior. Forty-six current profile/model/report/audio
files match across compilers (`build/pitch-rhythm-replay.log`).
The library remains 64 core / 19 adapter units;
this is focused evidence, not a new full-suite or package checkpoint.

This learns same-cell co-occurrence within known-pitch runs. Note-onset ownership,
durations, polyphonic voice roles, measured source clocks and wider delivery
remain open. The explicit coupled operator currently uses complete projection
maps; a consumer token with no known-pitch observation cannot be projected and
rejects. General partial consumer coverage remains outside this checked path.

## Preceding independent-dimension checkpoint — 2026-09-14

[Independent dimension blending](WAVE-STYLE.md#saved-profile-and-weights) now
selects or weights pitch separately from rhythm and its measured joint intensity.
Each dimension normalizes its own source-weight vector; zero excludes a source
from that model. The source table covers their active union, while full parent
archives preserve inactive evidence and repeated derivation. The current format
stores both coefficient pairs directly; no historical decoder or new format
variant was added. Superseded development blend files can be regenerated.

Both checked compilers pass controlled and recorded-rhythm workflows. Pixel
Sprinter contributes 144 admitted onsets from 348 selected source locations;
two independently checked monophonic harmonic WAVs supply pitches. A selected
style uses only Pixel rhythm/intensity and only the octave source pitch. A saved
second derivation retains the rhythm model exactly while adding the lower source
with pitch coefficients 1:2. The resulting three-source profile keeps all five
ancestry nodes and matches independently specified pitch training runs.

High, low and reblended melody variants each render 58 attacks / 290 notes into
604799 stereo frames. Switching pitch sources preserves all four accepted
key/tempo/onset/intensity provider models, tokens and states. Every melody attack
matches its solved pitch pass; actual WFC preview/MIDI and native output binding
pass. Controlled three-source variants also pass with 32 attacks / 160 notes.
The pitchless/zero-weight, pitch-without-intensity and invalid coefficient cases
are covered by existing extended fixtures; unavailable pitch selection preserves
the prior output archive.

One controlled case exposed the voice planner's 32-pass-backtrack limit at a
harmony-coverage pass. The operator now fixes each authored accompaniment voice's
pitch-class contribution while retaining compatible voicings; measured melody
stays absolute. This resolves the missing coverage without increasing budgets.
Failure messages retain status, failed pass and backtrack count.

Thirty-eight controlled/recorded profile/report/audio artifacts match across
compilers. Evidence: `build/style-dimensions-verified-{stable,trunk}/`,
`build/style-dimensions-recorded-{stable,trunk}/`, and
`build/style-dimensions-replay.log`. The initial controlled workflow log records
the diagnosed failure; `render-checks.log` records the final passing realization.
This is focused validation at 64 core / 19 adapters, not a fresh full-suite or
package claim. Pitch/onset joint learning, mixed-recording voice separation,
measured source clocks and wider delivery remain open.

Development format policy has been corrected for a fresh library: maintain one
current format per distinct artifact contract, with optional capabilities for
meaningful subsets. Do not preserve each development revision as a compatibility
commitment. Any future adapter or retained version must justify a concrete
consumer or interoperability need. See [project policy](../PROJECT.md#development-format-policy).

The style codec now uses one current PYST format with explicit optional intensity
and pitch capabilities. Superseded PYS1 readers/writers, parent-version promotion
and the per-profile version API are removed. Earlier generated PYS1 files must be
regenerated from source evidence; there is no migration path. Measurement-policy
identifiers remain for reproducibility. Historical byte-compatibility results
below describe earlier checkpoints and impose no ongoing requirement.

The current-format checks pass on FPC 3.2.2 and 3.3.1 i386-win32: onset-only,
intensity, pitch-without-intensity and combined capabilities round-trip; weighted
second derivation and selective pitch control retain their existing behavior.
Four fresh generated outputs pass actual WFC preview/MIDI and realized-note checks.
Twenty-seven current archives/reports/rendered files match across compilers.
Logs: `build/style-current-{stable,trunk}/`; replay:
`build/style-current-replay.log`. This is focused codec/caller validation, not a
new full-suite or package checkpoint. No old-format byte preservation is required.

[Saved measured pitch styles](PITCH.md#saved-pitch-styles-and-layer-control) now
connect native monophonic WAV measurement to the existing PYS archive, weighted
repeated blending and actual layered voice generation. Current profiles retain
pitch measurements/settings, unknown runs and canonical WFC models. Pitch and
intensity remain independent capabilities; unsupported active mixtures reject.
The named pitch pass supplies absolute melody while base context, onsets and
intensity continue to control accompaniment, clock, attacks and velocity.

Pitch-only edits preserve accepted key/tempo/onset/intensity states, then rebuild
dependent harmony/rhythm/voice realization. Bass, chords and note lengths remain
authored; melody/chord crossings are allowed to preserve measured register.
Pitch/onset joint history, independently weighted dimensions, mixed-recording
voice separation and automatic source tempo/downbeats remain open.
Current counts are 64 core / 19 adapters.

Both checked FPC compilers pass the maintained pitch-style workflow on i386-win32:
two actual harmonic WAVs each match 30 independently specified notes plus two
unknown cells; a saved two-source blend is blended again to weights 2:1. The
reloaded pitch model equals the independently specified weighted note-run corpus.
Baseline and pitch-edited renders each contain 17 attacks / 85 notes across
705600 stereo frames; every melody attack follows the solved pitch pass, with
actual WFC preview and MIDI parity. A cell-1 pitch edit to note 72 preserves all
four independent provider passes. Unsupported pitch 127 preserves all four prior
outputs. Detached evidence, frequency/note disagreement and unavailable-capability
failures pass; pitch also round-trips without intensity.

Nineteen current artifacts match across compilers. Sixteen previous artifacts
(four style fixtures, four standalone pitch files, four onset-style outputs and
four intensity-style outputs) retain identical bytes with each compiler.
Logs/listening files: `build/pitch-style-verified-{stable,trunk}/`;
comparisons: `build/pitch-style-replay.log`. Changed core, archive, operators and
existing fixtures were rebuilt with range/overflow/I/O checks; no owned-source
warnings/errors were reported. The new block in the maintained build script was
executed directly on both compilers; a full 64-core build is not claimed.

The preceding 63-core/19-adapter maintained stable build completed successfully,
including its pitch, dynamics, style and corpus workflows. Its terminal exit was
0 with no owned-source warnings/errors: `build/pitch-full-stable.log` and
`build/pitch-full-status.log`. That full checkpoint predates the version-3 style
extension; its focused evidence is recorded above.
Packages and additional targets are still unverified at these counts.

[Periodic pitch measurement and WAV note learning](PITCH.md) now supplies native
fundamental-frequency candidates, explicit tuning admission and an actual WFC
pitch learner. Unknown cells split training runs; weighted recordings remain
independent. The saved canonical pitch model generates native audio in a separate
process without reopening the WAV. This is a declared monophonic path, not
polyphonic voice separation. Its initially separate model path is now complemented
by the version-3 style integration above.

Both checked compilers pass 16 controlled periodic cases plus noise/DC, tuning,
channel and failure boundaries. All 30 pitched cells of an authored harmonic WAV
match an independent note reference; two silent cells remain unknown. The actual
saved WFC path validates, and all 32 generated pitches are verified in rendered
audio. Six source/model/report/audio files match across compilers; invalid channel
selection preserves prior learning artifacts. Pixel's mixed recording yields no
accepted periodic candidates in 160 cells under this default policy and is not
used as learned melody evidence. Logs: `build/pitch-{stable,trunk}/`,
`build/pitch-replay.log`. Current counts are 63 core / 19 adapters.

[Measured onset dynamics](ONSET-DYNAMICS.md) now extends saved WAV styles beyond
binary timing. A native forward-window RMS primitive retains source measurements;
admitted per-source relative intensity is learned together with onset presence in
an actual weighted WFC model. Version-2 profiles retain both models and RMS
evidence through repeated saved blending. Version-1 profiles retain their bytes.

The voice operator adds an intensity pass dependent on onsets, then rebuilds its
five voice passes with measured intensity constraints. An intensity-only edit
retains exact accepted key/tempo/onset tokens and latent states; onset edits also
regenerate intensity. Pitches, voicings, voice balance and gate lengths remain
authored. Missing active dynamics cannot silently blend with measured dynamics.

Both checked compilers pass native RMS/admission/weighted archive fixtures and
three recorded baseline/edit renders with actual audio/MIDI parity and every-tone
velocity checks. The two-source second blend has weights 2:1; intensity editing
preserves its 46 attacks/230 notes, while the rhythm edit yields 47/235. Twenty-one
files match across compilers. Five legacy audio/report/inspection files retain
previous bytes. An incompatible intensity pin preserves all four prior outputs.
Four version-1 fixture archives also retain their previous bytes.
A controlled native WAV also passes the added maintained build commands through
measurement, saved learning, render and output checks. Logs:
`build/style-dynamics-{stable,trunk}/`, `build/style-dynamics-replay.log`.
Current counts are 62 core / 18 adapters. This is focused evidence; full-suite,
source-package refresh, additional platforms and user listening approval remain
unverified. Broader measured voice roles, run scopes and musical structure remain
open within the larger outcome milestone.

[Named layer sessions](LAYERS.md#named-sessions-and-selective-regeneration) now
own models/relations and invoke actual WFC selective regeneration for positional
edits. The companion closes dependency chains, preserves independent latent
states and includes pending edited providers. Invalid edits and contradictions
preserve accepted results; replacing/clearing a failed mask permits recovery.

The saved WAV-style operator now accepts context/onsets before selectively
applying rhythm pins. Both checked compilers pass session ownership/closure/
recovery fixtures and recorded second-blend baseline/edit rendering. The edit
changes 46 attacks to 47 while retaining exact key/tempo state and clock;
companion audio/MIDI parity and native output binding pass. Evidence:
`build/layer-session-{stable,trunk}/`. Counts remain 61 core / 18 adapters.
Eight baseline/edit artifacts match across compilers; twelve unpinned/default/
context artifacts retain previous bytes. A contradictory edit preserves all four
prior output files. Comparisons: `build/layer-session-replay.log`.
The normal layer fixture includes these checks; a full-suite/package refresh
is not claimed. Fixed session models, one shared resolution and authored voice
realization remain limits; broader measured voice/joint style is still open.

[Reusable WAV onset styles](WAVE-STYLE.md) now connect measured source onsets,
saved key/tempo context, weighted independent recording samples and repeated
saved derivation to native audible generation. Three actual WFC context/onset
passes precede five dependent harmony/rhythm/voice passes. Source identities,
admission decisions, weights and full parents survive reload. Rhythm pins change
attacks while preserving exact independent key/tempo models, tokens and states.

Checked FPC 3.2.2 and 3.3.1 i386-win32 runs pass native admission/archive fixtures,
five recorded-music output variants and independent control checks. All 29
cross-compiler profile/report/audio/MIDI files match; eight stable legacy output
files remain identical. Contradictory pins preserve prior outputs. Logs:
`build/wave-style-{stable,trunk}/`, `build/wave-style-replay.log`.
Current counts are 61 core units / 18 adapters. This is focused evidence;
the maintained full build and source packages have not been refreshed.

The integrated onset-style path is delivered, but broad voice-style learning
remains open: source clocks are declared and pitches, voicings and gates are
authored. Whole-recording onset samples do not yet provide richer admitted
run scopes or learned voice/joint musical relationships. The milestone ledger
retains these limits and does not award its whole provisional percentage.

Progress planning now uses [outcome milestones](MILESTONES.md). The earlier 65%
estimate remains provisional; remaining allocations total 35 points. The next
major checkpoint targets roughly 12–15 points through integrated WAV-derived
style learning, persistence, controlled audible generation and repeated blending.
Small primitives support that outcome and are not reported as major milestones.

Interior sample loops now add one-shot intros and post-release tails through the
existing sample factory and shared linear/sinc trajectory addressing. The source
copies PCM once; instances own loop/release state. Bounded phase rebasing retains
all possible kernel history even when pitch increases later. Original sample
constructor behavior remains intact. [Contracts and evidence](SOURCES.md#interior-sustain-loops-with-an-intro-and-tail).

Both checked compilers pass exact expanded-PCM sinc comparison, loop/ownership/
release boundaries and existing source/resampling regressions. The 6.300083-second
native stereo demo matches byte-for-byte across compilers. Logs:
`build/sample-loop-{stable,trunk}/`, `build/sample-loop-replay.log`.
That checkpoint contained 60 core / 17 adapters. This closes the supporting
increment; full-suite/package refresh is not claimed. Next work follows the
larger milestone above rather than another independent small sample feature.

Saved context profiles now feed the independent-voice operator. Two actual WFC
key/tempo passes precede the five-pass harmony/rhythm/bass/chord/melody stack.
A known constant major/natural-minor key maps the authored score by scale degree
and rebuilds its dependent models/ranges/guide. Generated tempo drives preview,
stereo synthesis and MIDI, including changes through held notes. This realizes
base context as audible voices while retaining an explicit authored voice policy.
[Contracts and evidence](INDEPENDENT-VOICES.md#saved-context-feeding-the-voice-stack).

Checked FPC 3.2.2 and 3.3.1 i386-win32 runs pass D-minor/variable-tempo realization
and a derived profile combining native WAV key with Pixel's declared tempo.
Actual WFC PCM/MIDI parity and native MIDI round-trip pass; the fixture checks
every voice tone's scale membership, exact rational duration and artifact binding.
Both variants' four outputs match byte-for-byte across compilers. Stable unknown,
changing-key and incompatible-grid rejection preserves all prior outputs; the
default command's four files remain identical to the preceding full build.
Logs: `build/context-voices-{stable,trunk}/`, `build/context-voices-replay.log`.
The normal build includes the new fixture and context render/check; this is
focused evidence. Counts remain 59 core / 17 adapters. WAV voice extraction,
scoped key modulation, reverse negotiation and weighted/joint style remain open.

Explicit WAV context admission now connects measured tonal evidence to saved
key/tempo profiles. The native boundary preserves a caller-selected key or
unknown, full fit ranking and exact complete-cell scope. The operator requires
the reviewed source SHA256, records a caller-declared constant tempo and binds
the external measurement report by hash in the profile's admission policy.
No automatic key winner, beat detection or verified downbeat is claimed.
[Contract, commands and limits](WAVE-CONTEXT-ADMISSION.md).

Checked FPC 3.2.2 and 3.3.1 i386-win32 fixtures pass explicit/non-top/unknown
selection, silence rejection, fractional endpoints and scope budgets. A native
C-major WAV and Pixel Sprinter produce profiles that reload into actual two-pass
WFC generation. Pixel retains unknown key. Six output files match byte-for-byte
across compilers; wrong-source admission preserves both prior outputs. The
existing stable selector also combines the native key provider with Pixel's
declared tempo. Logs: `build/context-admission-{stable,trunk}/` and
`build/context-admission-replay.log`. Current counts are 59 core units and
17 adapters. The maintained build includes the new fixture and operator smoke;
this addition has focused checks, not a refreshed full-suite/package checkpoint.

The preceding maintained full build passed for the 58-core / 17-adapter tree
on FPC 3.2.2 i386-win32, with terminal exit code 0. All 53 maintained native test
programs are compiled/invoked by that workflow, including the companion parity
variants and output checkers. Core/WFC operator smokes complete through WAV
learning, saved acoustic/joint model reuse, pulse-event reconstruction and
PPQ/MIDI timed output. No owned-source warnings occur; existing companion/RTL
warnings remain. Full output: `build/foundation-full-stable.log`; scope/status:
`build/foundation-full-status.log`.

The normal build reproduces the focused reverb, modulated-delay and context
profile bytes. The established synthesis WAV retains SHA256
`07094fc2d977c43a0d96242b93bdb6ee4c806da7d9bfe1da6a40fa2351fcb3f9`.
Comparisons: `build/foundation-full-replay.log`. This closes the stale
full-build checkpoint; it does not replace the separate two-compiler package
evidence below or establish clean Git/remote CI/another target. The next-action
notes now distinguish delivered primitives and context selections from open
automatic/local WAV admission, richer voice/joint style, bandwidth and delivery work.

The source delivery checkpoint now contains all 58 native units and 17 WFC
adapters. Fresh core/WFC ZIPs contain 67/184 files and five/seven delivered
examples. The new native processing consumer joins bounded WAV reads, stereo
reverb through an effect chain, block writing, spectral analysis and stream
hashing without whole-clip storage. Its input is the existing authored core
example WAV. [Package contents, commands and limits](PACKAGING.md#current-source-packages).

Both extracted ZIPs compile every owned unit and run every delivered example
under checked FPC 3.2.2 and 3.3.1 i386-win32. All example MIDI/WAV/archive outputs
compare byte-for-byte across compilers; established outputs also match the
earlier 53-unit packages. The processor emits 111132 stereo frames, 109
observations, peak 0.1087234497 and one explicit second of tail.
Inventory confirms delivered source bytes/notices, the pinned WFC source and
absence of Phanes, compiled files and music assets. Logs/artifacts:
`build/package-foundation-{core,wfc}/`,
`build/package-foundation-inventory.log`, `build/package-foundation-replay.log`.
This is an extracted-source consumer checkpoint, not a full-suite, clean Git,
remote CI or tagged release claim. General layered style and weighted/joint
musical admission gaps remain open.

Saved context profiles now compose independent key/tempo providers from admitted
one- or multi-source bundles. Selection retains complete ordered parent archives,
original source scopes/orders and actual WFC models; the derived result can be
selected again. The versioned `.pcp` format validates digests, bounded ancestry,
timing compatibility and embedded learner replay. No observation pooling,
weighting or inferred joint evidence is introduced.
[Contracts and evidence](CONTEXT-PROFILES.md).

The native selector imports `.ptc` sources or selects two `.pcp` parents.
The context demo saves/reloads two-stage selections before actual four-pass
generation. It rebuilds its authored gate model/projection for the selected
tempo vocabulary; stale alternatives referencing absent provider tokens reject
in WFC. Key pins still control bass, while selected tempo controls gates and
exact native duration. General dependent-layer compilation remains open.

Checked FPC 3.2.2 and 3.3.1 i386-win32 runs pass the new profile fixture, updated
demo and both selector modes. All four profile artifacts compare byte-for-byte
across compilers. The four WAVs and original bundle/declarations also match the
earlier context archive checkpoint. Logs: `build/context-profile-{stable,trunk}/`
and `build/context-profile-replay.log`. That checkpoint had 58 core units and
17 adapters. Normal builds include this workflow; full-suite and package refresh
are not claimed. General style profiles, weighted blends, joint voice evidence
and automatic WAV admission remain explicit gaps.

Stereo reverberation now extends the synthesis/effect fundamentals through the
existing delay storage, effect-chain and bus contracts. The new
`TReverbEffect` combines four damped combs and two true allpasses per channel,
with copied delay arrays, nominal decay, damping, diffusion, width and dry/wet
controls. Processing stages both channels before committing and allocates no
memory per frame. Direct failures preserve history; reset clears the tail.
[Signal contract, primary references and evidence](REVERB.md).

Checked FPC 3.2.2 and 3.3.1 i386-win32 runs pass the independent transfer-function
oracle, analytic impulse/decay, stereo ownership/failure and clip-partition
checks, plus existing effects regression. Both 21-second native listening
examples compare byte-for-byte with peak 0.1616458446 and measured nonzero tails.
Logs: `build/reverb-{stable,trunk}/`, `build/reverb-replay.log`.
The normal build includes the new fixture and demo. That checkpoint had 58 core
units and 16 adapters. This does not establish perceptual room fidelity, general
listening approval, full-suite completion or refreshed source packages.

WAV spectral analysis now uses a shared window-source engine. The clip wrapper
and new WAV adapter retain identical FFT math; the adapter caches overlap and
reads each sample once. Features publish only after complete success, including
custom-source count/finiteness failures. Stream SHA256 adds fixed 8192-byte input
storage through the existing native algorithm. The standalone learner uses both,
retaining its former source/sample/FFT budgets and validating a second digest
before publishing source information. [Contract and evidence](ANALYSIS-WAVE.md).

Both checked FPC 3.2.2 and 3.3.1 i386-win32 builds pass the new window fixture,
extended hash fixture and existing actual WFC learning/generation fixture.
Original Pixel Sprinter and Opening Theme JSON/model outputs are byte-identical
to an independently retained earlier learner binary and across both compilers.
Logs: `build/analysis-wave-{stable,trunk}/`, `build/analysis-wave-replay.log`.
The normal build includes the new fixture. That checkpoint had 57 core
units and 16 adapters. Full-suite/package refresh is not claimed. Other corpus
tools still use their existing loading paths; automatic musical admission,
layered style profiles, weighting and derived blends remain separate work.

Bounded seekable WAV input now shares the native decoding path. The new
`TWaveFrameReader` scans RIFF/RF64 structure, then reads up to 65536 frames
per call with a fixed 4096-byte scratch buffer. It handles 64-bit size/frame
coordinates, RF64 size tables, arbitrary chunk ordering and existing PCM/float
formats. Source/sample failures poison the reader while preserving the last
confirmed logical frame position and prior assigned output. Argument errors are
recoverable. [Contract, limits and evidence](WAVE-READING.md).

`DecodeWave` uses a retained read-only input view; `LoadWave` no longer
buffers the complete encoded file. Both still enforce the full-clip sample cap.
The new native transcode operator joins bounded reads to the existing
RIFF/RF64 PCM16 writer. Normal builds include a focused reader fixture and
canonical PCM16 transcode smoke. That checkpoint had 56 core units and 16 adapters;
the existing source ZIPs remain earlier delivery checkpoints.

Checked FPC 3.2.2 and 3.3.1 i386-win32 runs pass reader, existing core and
streaming-writer checks without vendor paths or authored warnings. RF64 tests
cover a size-table chunk, 32-bit-field precedence, malformed metadata and a
virtual 8589934684-byte source with 2147483651 stereo frames. Reading its final
frame consumes only 84 total header/sample bytes, with no large file allocation.
Complete physical multi-gigabyte decoding is not claimed.

Pixel Sprinter's 1512000 frames and Opening Theme's 3969000 frames transcode
exactly against both compilers and a retained earlier decoder binary; Pixel also
replays exactly across 137/65536-frame input blocks. Logs and outputs:
`build/wave-read-{stable,trunk}/`, `build/wave-read-replay.log`.
The earlier binary's identity/timestamp is retained in
`build/wave-read-stable/earlier-converter.log`. Existing corpus learners still
have their own source/analysis budgets. Non-seekable input, extensible formats,
metadata round trips and atomic output replacement remain separate work.

Fractional delay history and stereo modulated delay now expand the native
synthesis/effect fundamentals. `TFractionalDelayLine` separates nonmutating
fractional taps from one history push; the existing fixed `TDelay` reuses it.
`TModulatedDelayEffect` owns independent left/right automation curves and
fixed history buffers. Delay motion uses the existing LFO/point/affine API,
with explicit mix, signed feedback and capacity. A stereo call validates all
results before committing either history, outputs or the shared control clock.
[Contract and listening guide](MODULATED-DELAY.md).

Checked FPC 3.2.2 and 3.3.1 i386-win32 runs pass the focused fixture plus existing
core/effect fixtures without vendor paths. Analytic tap and legacy recurrence
checks pass; moving stereo output differs from the independent absolute-history
reference by at most 3.89e-17. Whole and split clips/tails match exactly, including
reset and copied-control lifetime. Late right-output rejection preserves both
histories and phase. Logs: `build/delay-modulated-{stable,trunk}/`.

The native comparison renders dry, chorus and feedback-flanger versions of one
phrase: 324000 stereo frames at 24000 Hz, peak 0.1629921645. Both compiler WAVs
are identical, SHA256:
`6e744c81c940ce9b36345eca464f778e0df8550568208c15f0d6ae14c622e69b`.
The focused fixture and demo are in the normal build. That checkpoint's source counts:
55 core units and 16 WFC adapters. Existing package archives predate this change;
broader style, waveform inference and delivery goals remain open.

Context learning can now be saved as an owned bundle containing admitted source
names/hashes/policies, complete scoped grids, independent key/tempo model orders
and both canonical actual WFC models. The new standalone `.ptc` archive binds
contract versions and all payload bytes with SHA256. Loading validates bounds,
then rebuilds both models from the saved evidence and requires exact canonical
text equality. This is WFC learner replay, with no WAV reanalysis or execution
of stored policies. [Contract and scope](CONTEXT-ARCHIVE.md).

The native context demo writes two authored source declarations and the bundle,
frees original learning, reads the bundle back from disk, checks external source
hashes, and frees the loaded bundle before using copied models. All four actual
key/tempo dependency combinations retain their expected tokens and exact native
rendered duration. Archive fixtures cover one/two-source bundles, ownership,
separate orders, replay and valid-digest semantic/count/version/trailing failures.
Checked FPC 3.2.2 and 3.3.1 i386-win32 runs pass under
`build/context-archive-{stable,trunk}/`. Final compilation removes an initial
development-compiler warning from exhaustive enum selection; current owned
archive code compiles without warnings. The normal build includes the fixture.

The archive, source declarations and all four WAV files are identical across
compilers; the WAVs also match the preceding direct-learning demo. Direct
comparisons/hashes: `build/context-archive-replay.log`. Bundle SHA256:
`5ecd85bda1061e8da2373356e42fffe828938198436104b25dd55046f1fa827b`.
That context-bundle checkpoint had 54 core units and 16 WFC adapters. Existing source
packages predate these context additions. This context bundle does not yet
provide voice/joint models, per-layer weighting, blend lineage or resume state.

The preceding typed musical context step added a native owned timeline and an actual WFC
provider adapter: then 54 core units and 15 adapters. Key changes include explicit
unknown values and share the exact PPQ tempo clock. Scoped grids retain their
source tick offsets and reject changes inside cells. Each admitted song/excerpt
remains a separate learning sample; key/tempo models use canonical versioned
tokens and require a common explicit PPQ/step. Generated providers reconstruct
an exact output clock without BPM rounding. [Contract](MUSIC-CONTEXT.md).

The new native demo learns two authored context excerpts and bass/gate models,
then exercises four actual WFC passes: key -> bass and tempo -> gate length.
All four independent key/tempo pin combinations produce the expected descendant
tokens and exact durations: 48000 or 57600 stereo frames at 24000 Hz. This is
controlled evidence for context dependency and rendering, not WAV key inference,
general selective graph reuse or reusable style blending.

Checked FPC 3.2.2 and 3.3.1 i386-win32 runs pass native scope/ownership/clock
fixtures, complete-model comparisons against separate explicit WFC samples at
orders 1..4, and the four-pass listening demo. Artifacts/logs:
`build/context-{stable,trunk}/`. Native core checks use no vendor paths.
Both fixtures and the demo are included in the normal build. Existing source
packages remain the earlier 53-core/14-adapter checkpoint and exclude this work.
All four context WAVs compare byte-for-byte across compilers; hashes and direct
comparisons are recorded in `build/context-replay.log`. New owned units have
no warnings; existing companion/FCL warnings remain.

The preceding periodic-control step extended the existing native automation API: immutable
sine/triangle LFOs, owning affine scale/offset composition and semantic cloning.
The five existing voice routes remain unchanged. Each note retains its complete
control definition; scheduler callers can release originals after admission.
Integer-frame periods, conservative excursion bounds and maximum depth eight
keep the contract explicit. These are sound-realization fundamentals beneath
the accepted WFC layer graph, not new key/tempo providers or learned style APIs.

Checked FPC 3.2.2 and 3.3.1 i386-win32 runs pass the new control fixture and
existing modulation/scheduler fixtures. Independently calculated point controls
match every rendered and scheduled sample exactly; ownership and high-Int64
phase/depth boundaries pass. Both compilers render identical 288000-frame,
24000 Hz stereo listening examples with plain/vibrato/tremolo/filter-pan sections.
WAV SHA256:
`801b0a6af642307c3b71bb6423f7cb9323a8c9f4302582d155552d5d3d651ee9`.
The legacy modulation WAV retains its earlier hash. Logs and WAVs are in
`build/control-curves-{stable,trunk}/`; the fixture/demo are integrated into the
normal build. [Control contracts and listening guide](MODULATION.md).
At that checkpoint the source count was 53 core units and 14 adapters. The source packages
below predate this automation extension and have not been regenerated for it.

The preceding source-delivery checkpoint contains all 53 core units and 14 WFC adapters. The core
ZIP contains 61 files and four native examples; the WFC ZIP contains 175 files
and six examples. Every owned unit and delivered example builds/runs using only
extracted sources on FPC 3.2.2 and 3.3.1 i386-win32, with identical MIDI/WAV/event
archive outputs. New public examples exercise instrument note bindings and a
two-recording event archive loaded from disk after freeing original learning.
[Fifty-three-unit package evidence](PACKAGING.md#earlier-fifty-three-unit-package-checkpoint).

Artifacts: `build/package-events-{core,wfc}/pythian-source.zip`. ZIP inspection
verifies exact source bytes/notices and companion pin, excluding Phanes, binaries
and music. An external stable consumer additionally loads the real pulse archive
and verifies every sample of its 1207709-frame output using only extracted library
paths; WAV, JSON, model and archive replay exactly. Logs are in each package's
`consumer-check/`, `consumer-development/` and WFC `consumer-recorded/`, plus
`build/package-events-inventory.log`. The earlier full suite retains its 52-unit
scope. Clean Git/CI and other targets remain separate delivery work.

Recorded-event learning is now persistent through a distinct opaque attachment
in the existing measured-corpus envelope. It retains exact binary64 centers,
accepted source intervals/runs/onset flags, duration quantum, admission-policy
text, source attribution and actual WFC model bytes. Loading reconstructs
descriptors/token assignments and independently validates vocabulary, sample
lengths, state observations and start/end counts without FFT, clustering,
onset tracking or WFC learning. [Contract and evidence](EVENT-ARCHIVE.md).

The event operator now writes a reusable `.pyac` alongside its audio/report/model
and accepts `--load` with only the archive and admitted WAV files. Both installed
compilers pass orders 1..4, exact round trips, ownership and valid-digest semantic
rejections. The real two-recording pulse corpus reloads and reproduces all 64
events / 1207709 frames with reversed source arguments. Every PCM sample passes
the independent source/fade checker; WAV, model and archive bytes replay exactly.
Duplicate-source loading preserves all four prior outputs. Logs are under
`build/event-archive-{stable,trunk}/` and `build/event-archive-replay.log`.
This is event-model persistence, not completion of weighted per-layer styles,
controlled audible blending, fundamental synthesis or platform delivery.

Shared recorded-event learning now combines selected source intervals from one
measured corpus into a single event palette and actual WFC model. Separate songs
and admitted runs remain independent training samples; excluded intervals train
neither palette nor model. The new native `pythian.event.merge` operator binds exact
source hashes and onset reports, supports onset or pulse admission, and records
all source/output coordinates. Native passage rendering now accepts multiple
sources with explicit identity-aware joins. The core remains 53 units; there are
now 14 WFC adapters including recorded-event persistence. [Contract and evidence](EVENT-CORPUS.md).

Focused FPC 3.2.2/3.3.1 i386-win32 checks compare the complete shared model with
independent manual training samples, validate ownership/failure boundaries and
check native samples across recording switches. Both real CC0 recordings pass:
pulse mode learns 191 events / 12 runs / 71 tokens / 145 states; onset mode learns
1251 events / 2 runs / 100 tokens / 625 states. Each produces 64 verified source
fragments, with every output PCM sample independently checked. Both recordings
contribute training, but these fixed-seed outputs each select members from only
one recording; this is not evidence of audible two-song style blending. Existing
Pixel pulse output is unchanged and its full model/path/PCM checker still passes.
Logs are in `build/event-merge-{stable,trunk}/`; replay is recorded in
`build/event-merge-replay.log`. Saved event-model admission is now implemented in
the subsequent checkpoint above. Weighting and broader synthesis, style and delivery
requirements remain open.

The instrument map now connects directly to `pythian.music.render`: single or
per-source-voice instrument bindings expand pitch/velocity zones through the
existing exact tempo clock. Reports distinguish source gates from expanded tones;
the common 65536-tone ceiling includes every layer. The MIDI-round-trip instrument
audition retains its direct-frame output. Focused sequence fixtures and existing
native note fixtures/public example pass on both installed compilers, including
tempo-crossing PCM, sub-frame admission, late failure preservation and expansion
capacity. Evidence is under `build/instrument-sequence-{stable,trunk}/`; see
[instrument integration](INSTRUMENTS.md#using-the-existing-renderer-and-scheduler).
All affected callers rebuild on both compilers, including the MIDI command and
both WFC voice/layer operators. Actual WFC music projection/clock/codec checks
and the four-pass layer audition pass. The instrument WAV is byte-identical
across compilers and to the prior direct-frame demo; the public notes example
retains its MIDI/WAV hashes. `build/instrument-sequence-replay.log` records replay.
The source count remains 53. Earlier full-build and 52-unit package evidence
retain their recorded scope; this change does not claim style-profile learning.

The measured source-event path now connects local pulse tracking to actual WFC
learning and reconstruction. Admission retains source coordinates and excludes
gaps, uncertain joins, irregular final durations and unaligned endpoints.
The native independent-voice consumer now exercises WFC training documents,
five learned passes, exact-harmony planning and streamed realization through
Pythian's renderer, with a separate stereo synthesis example.
Expanded precursor dispositions and refreshed 52-unit source packages are
present, with extracted-package pulse-learning and voice/MIDI replay. The full
objective is **not complete**.

The named precursor audio/music source inventory is now reconciled: all six
remaining WFC support units have complete dispositions, and Phanes's MIDI corpus
helper has a full-unit reconciliation. The retained companion already implements
selective finite regeneration and individual ensemble voice locks. Its two actual
pipeline fixtures pass on both installed compilers. The current package refresh
and [Phanes removal audit](REFERENCE-REMOVAL.md) have passed. The Phanes gitlink,
configuration stanza and temporary worktree are removed; WFC and Athena remain.
Captured tonal selections preserve the final precursor regression in native tests.
This closes the extraction/removal gate, not the full synthesis/learning/delivery objective.

- Root standards entry point, project decisions, build orchestration, and docs.
- The complete post-removal build passes on existing FPC 3.2.2 i386-win32 in
  `build/removal-audit/post-removal-build.log`, including native/WFC fixtures,
  chord MIDI and operator smoke workflows, with no owned compiler warning.
  Phanes source was absent for the entire run. Earlier development
  full builds and current focused checks retain their stated scope. Core-only
  and WFC source ZIP snapshots compile their complete
  recorded unit sets and run external consumers after extraction, without Phanes.
  Refreshed source snapshots include all 52 core units and 12 WFC adapters;
  the same ZIPs compile every delivered owned unit and run all included examples
  on both compilers. External stable consumers reproduce recorded pulse events
  and independent voices/MIDI from extracted library sources. ZIP inspection
  confirms source/notices and excludes Phanes, binaries and music assets.
  [Removal-checkpoint package evidence](PACKAGING.md#earlier-fifty-two-unit-package-checkpoint).
  Native SHA256 preserves existing archive/source identities and full recorded
  passage replay while removing the development-only FCL hash dependency.
- Fifty-three standalone core units, including exact PPQ clocks, immutable notes,
  shared measured corpora, validated archives, activity segmentation and bounded
  grain planning with measured continuity costs, polynomial oscillator correction
  and shared windowed-sinc resampling, immutable automation, additive/FM/PM,
  harmonic-limited wavetables and pitched sample sources, biquad/EQ, dynamics,
  owning effects, filtered feedback echo, ordered stereo bus routing and
  bounded streaming voices with atomic future-note replacement.
- Native [instrument zones](INSTRUMENTS.md) now map pitch/velocity to ordered
  layers of existing sources/voices. Detached plans support offline rendering and
  atomic scheduler batches. Four authored sample zones demonstrate keyboard splits
  and velocity overlap in a 7.5-second audition. Focused checks pass on both
  compilers; the preceding packages/full stable build cover 52 units, not this
  newest instrument unit.
- Bounded chord-frame MIDI is now extracted into `pythian.midi.chord`, using
  renderer-independent `pythian.chord` data and a shared WFC frame projection.
  Native canonical/ownership/failure checks and full actual companion bytes/plans
  pass on both compilers, including 16 full-pitch channels and maximum-tick
  counting. Existing audio PCM parity remains intact. The voice demo now streams
  all 88 notes with declared meter and matches the actual full-score MIDI export;
  both WAVs remain unchanged. [Evidence](CHORD-MIDI.md). These two units postdate
  the recorded fifty-unit packages and full stable build.
- Native two-pass MIDI streaming now extracts the complete WFC transport unit:
  scalar track plans, bounded forward byte blocks, long-delay bridges, detached
  payload admission and explicit replay failure. Actual WFC bytes/counts/signatures
  and canonical native codec output agree on both installed compilers. The native
  example streams a 177-byte, 16-note authored file and the existing MIDI renderer
  produces 180313 stereo frames at 44100 Hz; both artifacts replay byte-for-byte
  across compilers. Music regression checks pass. [Contract/evidence](MIDI-STREAMS.md).
  This unit is included in the refreshed fifty-unit packages; its initial
  focused checks predated those snapshots.
- Native note/tempo MIDI export now plans explicit channels and stable
  metadata/off/on ordering, rejects ambiguous channel/pitch overlaps and reuses
  the native streaming transport. The independent-voice demo exports all 88
  generated notes on three channels with an exact strict-import round trip.
  Native golden/ownership/admission checks and actual WFC note/tempo parity pass
  on both installed compilers. Full source review closes score and MIDI import/
  export dispositions; symbolic partitions, lane allocation and meter/padding
  policy remain in WFC. [Contract/evidence](MIDI-EXPORT.md). The refreshed package
  includes it and a native two-voice note/MIDI/audio consumer.
- Explicit PPQ-grid and MIDI output gates apply bounded fades and exact rests
  after WAV reconstruction. Input sample positions and measured activity labels
  remain unchanged; source beat alignment remains open.
- Fourteen WFC adapters: PCM conversion, acoustic learning, constrained generation,
  note projection, persisted corpus/model admission, actual rhythm-cell learning
  and paired acoustic/activity learning, locks, validated joint archives and
  explicit musical attack alignment, bounded learned sequence continuation and
  negotiated layers with correlated projection constraints and joint
  acoustic/duration/onset event learning, shared recorded-event corpora and
  persisted recorded-event admission.
- Joint archives retain the actual trained model and exact activity policy.
  Load independently validates counts from stored features without FFT, palette
  training or WFC learning; remix uses the stored policy for source selection.
- Integer anchor mapping reports exact signed errors and rejects unresolved
  attack collisions. A native timed remix combines PPQ/MIDI onset-candidate
  constraints, saved-model generation and exact output articulation. This does
  not establish source beat/transient accuracy.
- Phanes duration histograms and diatonic fits now live in `pythian.tonal`,
  with explicit caps, optional weighting, complete rankings and score gaps.
  Actual precursor selection parity passes. MIDI and WAV/stored-chroma profiles
  share this core API, with no forced scale mapping or verified-key claim.
- WFC's incremental ensemble clock is extracted with exact fractional carry,
  resumable value snapshots and atomic overflow rejection. The actual companion
  clock agrees throughout the shared range; native limits are explicitly wider.
- Complete Phanes preview/player inventory now distinguishes extracted signal
  and scheduling mechanisms from browser/application policy. Combined native
  tempo-candidate admission and clock publication preserve crossing note gates,
  other groups and echo against an independently timed audio reference.
- Learned sequence chunks retain the exact actual WFC latent predecessor,
  including higher-order history. Failed chunks preserve prior output and allow
  retry; observed-end admission seals the stream. A native saved-joint command
  reconstructs 3072 grains across twelve validated chunks into 71.4 seconds of
  stereo audio without FFT/relearning, with exact source attribution and replay.
- Complete Phanes track-unit review assigns its authored phase templates,
  duration/style/shaping choices to application composition policy. Generic
  learned continuation now uses WFC's existing segment and section-seed APIs;
  musical macro-form controls remain open. Ensemble/arrangement source review
  is now complete with explicit companion dispositions.
- Continuous sinc conversion now retains bounded history across input blocks,
  carries exact rational source position and handles centered lookahead and EOF.
  Scheduled 48000 Hz synthesis renders directly to a 44100 Hz sequential WAV
  using a 151-frame ring, with no complete intermediate clip allocation.
- Optional ACID declarations now produce checked source bar grids; reusable
  passage aggregation and stereo rendering feed the existing actual WFC learner.
  The Pixel Sprinter example retains full bars with an explicit opening, reprise
  and source ending, with source/model mapping and all-sample verification.
- Complete Phanes generator/wire/worker/corpus-tool review identifies application
  policies and extracts reusable negotiated layer solving through actual WFC.
  Coupled voices, observed pairs and temporal intervals now have focused failure,
  retry, correlation and ownership evidence plus a native synthesis example.
- Native note rendering now accepts explicit source-voice bindings, retaining
  different timbres/pan through one exact clock. WFC ensemble reconstruction
  preserves independent held chords and bass gates through tempo changes, with
  detached native notes and failure-preserving planning. The coupled-layer demo
  uses the common planner and retains its original WAV bytes.
- WFC's complete ensemble audio unit now has a native extraction. Independent
  chord holds retain phase; a bounded delayed mix ring applies release within
  unknown-length gates, and end input drains without a tail. Native frame-time
  admission is separate from the WFC/PPQ bridge, whose rejected admission restores
  the clock. Actual WFC PCM agrees at three sample rates and varied block sizes;
  a finite-gate oracle and eight-second streamed native WAV example pass.
- A native learned ensemble consumer now derives voice capacities from the full
  vocabulary, plans a bounded correlated phrase with regular rhythm and a C-major
  ending, and realizes it through the actual WFC ensemble stream. Generated holds
  cross segment boundaries without audio changes; all PCM matches the precursor.
  Complete arrangement-unit review keeps its finite source-owned section and
  detached public-tail policies with the companion.
- Complete WFC form, independent-voice training/graph/stream and sequence-domain
  analysis reviews now distinguish authored musical catalogs from measured WAV
  evidence. Phanes's types, dimension widget and browser entry point have explicit
  application dispositions. The [boundary review](PRECURSOR-BOUNDARIES.md) names
  the final removal audit. The independent-voice consumer is now exercised
  through the actual training bundle, graph and stream, with full-vocabulary
  native capacity admission. A finite authored harmony/rhythm guide coordinates
  separate bass, chord and melody models; all preview PCM matches actual WFC.
  Native per-voice synthesis also renders the generated score in stereo.
- Native synthesis/MIDI rendering, WAV learning, granular remix and audio inspection tools.
- Optional PCM onset localization retains original feature/activity identities
  and reports unresolved candidates, clipped context and search-edge maxima.
  A native five-case WAV laboratory records authored event positions, matched
  errors and misses. Native inspection also runs on both attributed recordings;
  their unannotated candidate counts do not establish source timing accuracy.
- An independent sample-rate-aware timing preset recovers all eight controlled
  percussion attacks spaced 60 ms apart, compared with five under the wider grid.
  Original learning defaults and archive policies remain unchanged. Optional
  native audition WAVs mark resolved locations with short cues and retain exact
  output identity and gain settings for operator timing review.
- Native event planning now turns admitted onset locations into a complete source
  partition with original candidate identities and explicit exclusion decisions.
  Existing passage aggregation connects exact boundaries to archived acoustic
  measurements. Actual WFC learns joint acoustic/duration/onset symbols; the native
  event-remix tool renders matching source intervals at their exact durations.
  Both recorded-music outputs pass input/model/path and every-sample verification.
- Native beat-grid estimation now ranks tempo/phase hypotheses from weighted
  admitted onset positions. Coherence, support, coverage and matching error remain
  measurements rather than confidence. Controlled antiphase percussion and a
  polyphonic recording recover their authored clocks; the tempo-change case
  exposes the global model's limitation. The shared cue renderer preserves the
  old onset audition exactly and supports explicit candidate listening.
- Local beat tracking now combines Hann-weighted windows through a bounded
  tempo/phase path and records evidence gaps and restarts. Optional source-onset
  alignment retains raw points, selected observations and every adjustment.
  The unchanged tempo-change WAV improves from 15/24 matches and 11 extras under
  one fixed grid to 24/24 and no extras in the authored evaluation interval.
- Native anti-aliasing comparison renderer and WAV sample-rate converter.
- Native modulation demo combining extracted pitch/cutoff ramps, moving pan,
  separate additive partial decays, vibrato and oversampled FM/PM.
- Reusable source factories and per-note instances connect all five source
  families to one mono/stereo tone renderer; native source demo included.
- Eight biquad/EQ types, linked compressor/limiter, smoothed gain and owning
  serial effect chains; tone filtering and native effects comparison included.
- Bounded ordered buses with pre/post-fader sends, separate music/effects gain
  control and continuing filtered echo. Native five-bus example writes its
  output in bounded blocks and exercises return mute with preserved history.
- One shared playing-note renderer serves offline and streaming synthesis.
  Scheduler admission reserves pending/active voices, clones automation,
  preserves exact starts/gates and groups, releases committed voices and
  atomically replaces future notes. Native seven-second live-edit demo included.
- Focused fixtures plus one-shot and persisted multi-recording learning,
  generation and reconstruction on two published recordings.
- Joint WFC sequence learning from stored measurements, simultaneous acoustic
  and activity locks, action-specific grain pools, and a native remix command
  with explicit source-window onset/sustain/silence controls.

The retained WFC/Athena submodules and unrelated staged additions are preserved.
No dependency source was edited; the temporary Phanes reference was removed only
after its extraction audit. No tool installation or global environment change was
needed. Build outputs and local logs are ignored.
The preceding pulse-learning turn made verified progress. This continuation
revalidated that state, added independent-voice capacity admission and a real
training/graph/stream consumer, and recorded the user's modular style vision as
an explicit architecture requirement. The earlier beat-grid checkpoint exposed the
constant-tempo limitation. Local tracking now follows the controlled tempo change
and retains both raw hypotheses and explicit source-onset adjustments. The native
impulse fixture separately checks equal-strength attacks, gaps and disabled
alignment. Pixel and Opening execute the new path without source tempo metadata;
their output counts are not annotated beat accuracy. Recorded-music annotations,
broader tracking behavior, score/ensemble support inventory, independent-voice
integration and the full synthesis scope remain open. Companion form labels
must not be inferred from acoustic palette identifiers or a selected pulse path.
The full objective is unchanged. The user correctly identified shared-stream.wav
as a longer-generation integration artifact; it is not a musical-quality result.
Prioritize musical structure and listening evaluation in subsequent generation
work rather than treating additional duration as evidence of coherent music.
There is no external blocker; the full goal remains active.

The preceding five-unit source review made progress by recording complete
dispositions. The subsequent review closed the final six named WFC units and
reconciled Phanes's complete MIDI corpus helper. No new audio extraction was
needed from these symbolic support units. Actual companion fixtures now verify
selective finite regeneration, provider reuse, individual voice locks and rollback
on both installed compilers. The architecture notes distinguish this existing
specialized capability from future semantic layer/style APIs. All 25 pinned WFC
music/MIDI source filenames have inventory entries; full source dispositions and
runtime evidence retain their separate scopes. Edited Markdown targets/LF and
unchanged submodules were checked. The following package/removal turn retains
the 52-core-unit and 12-adapter implementation, refreshes the delivered snapshots,
preserves actual tonal reference results and completes the Phanes removal audit.
Full delivery and synthesis/learning expansion remain open, with no external blocker.

## Verification evidence

Instrument checkpoint: the previous reference-removal turn made verified progress.
The next synthesis extension adds `pythian.instrument`, its native fixture and
audition. Both checked compiler runs pass range/overlap/ownership/failure checks,
independently authored layered PCM and actual scheduler admission/PCM16 comparison.
Logs are in `build/instrument-{stable,trunk}/checked-{build,test,demo}.log`;
`build/instrument-replay.log` records the audition comparison. No owned compiler
warning was introduced. `tools/build.ps1` includes the new fixture/audition; the
entire suite and source packages have not been refreshed for this 53-unit state.

Earlier package/removal checkpoint: `build/package-complete-core/` contains a
59-file ZIP with all 52 core units; `build/package-complete-wfc/` contains a
170-file ZIP with those units and 12 adapters. Both compile every owned unit and
run all delivered examples on both installed compilers. Final example replay,
full notices/current-source inspection, actual chord-MIDI parity, recorded pulse
learning/PCM verification and all-four-artifact voice replay pass. Commands, logs
and precise scope are in [packaging](PACKAGING.md#earlier-fifty-two-unit-package-checkpoint) and the
[removal audit](REFERENCE-REMOVAL.md). The native tonal fixture now always checks
the same 32 precursor-derived root/mode pairs, measured immediately before removal;
it passes on both compilers without reference imports. Phanes is absent from
`.gitmodules`, the index and its source worktree. WFC/Athena pins remain unchanged.

Support review: unmodified `vendor/wfc/test/wfc_music_passes_test.lpr` and
`wfc_music_ensemble_passes_test.lpr` were rebuilt with `-B -Sa -Cr -Co -Ci -gl`
and `-Fuvendor/wfc/src`. Separate `build/support-review-stable/units` and
`build/support-review-trunk/units` prevent compiler artifact mixing. The first
fixture passed 48 checks and the second 99 on each compiler, including selective
closure, dirty providers, voice-only locks, contradictions and rollback. Exact
compiler IDs are in their `*-build.log` files; `*-run.log` records runtime results.
No dependency source or owned runtime source was changed. This is focused
companion evidence, not another full Pythian build or a new public adapter API.

After reference removal, `tools/build.ps1` with the verified stable compiler
completed successfully in `build/removal-audit/post-removal-build.log`. This
exercises the current native and WFC fixtures, updated standalone tonal reference
checks, chord MIDI, voice preview/MIDI and all normal learner/remix smoke workflows.
No owned Pascal warning was reported; existing WFC/FCL warnings remain. The
removed source directory was absent and no owned Pascal/tool file references a
Phanes unit. No new full development-compiler suite or other-platform result is
claimed beyond the package and focused evidence above.

Compilers: existing FPC `3.2.2-rrelease_3_2_2-0-g0d122c4953` and
`3.3.1-20634-gd7f522a561`, i386-win32. Successful full compile,
link, and execution verified their capability. Build flags include
`-B -Sa -Cr -Co -Ci -gl`. Core and adapter unit outputs are separate.
Latest independent-voice consumer checks pass on both compilers:
`build/voices-stable-checked.log`, `build/voices-development-checked.log`.
The music fixture checks full singleton vocabularies, chords after rests,
invalid combined-voice/missing models and preserved capacity results, alongside
its existing score/clock/SMF checks. No owned compiler warnings were introduced.
Existing upstream warnings and unused-variable notes remain.

The demo learns five order-2 models from two authored native 32-cell phrases
through actual training documents. A 64-cell independent-voice plan has exact
collective harmony, shared rhythm, ranges and pair constraints. A direct local
stream experiment reached a finite dead end at segment 2; the final consumer
plans the bounded phrase before streaming without relaxing constraints.
The default 13 segments retain 21 voice holds, exact model predecessors and
complete planned latent paths. All 769546 preview frames match actual WFC PCM,
including a mid-hold tempo change. Native note projection and separate voice
bindings render 88 notes into 774838 stereo frames (17.5700 seconds with release).

Stereo: `build/3.2.2-i386-win32/voices.wav`, SHA256
`b70aaa5e307387a3e936081931b6296592e86f1df67ed30936fe09b1a6ac0340`.
Its `.preview.wav` companion has SHA256
`d3000c49f3f173ffa4bc40dcf83951dc0f6d52beacb1077dc36a07efb1049d2d`.
Both WAVs and JSON replay exactly across compilers
(`build/voices-compiler-replay.log`). Seven-cell realization retains identical
audio under the same full plan (`build/voices-segment-replay.log`).
The combined-ensemble WAV/report also remain byte-identical after the shared
capacity scan refactor (`build/voices-ensemble-regression.log`).
Native stereo inspection is `build/voices-stereo-inspect.json`.
The build includes the new consumer in verification mode. No fresh full suite
or source ZIP is claimed. [Independent voice evidence](INDEPENDENT-VOICES.md)
distinguishes the bounded example, extracted streaming preview and offline
stereo render from unbounded generation or learned musical macro-form.

Earlier pulse admission and learning checks pass on both compilers:
`build/pulse-events-stable-final.log`,
`build/pulse-events-development-final.log`. Native fixtures build without vendor
paths; the WFC fixture proves that separate runs exclude an artificial transition
that a deliberately flattened control model learns. Final interval ratios are
checked independently of raw seam flags. No owned warnings remain; existing
upstream warnings and unused-variable notes remain.

Pixel admits all 79 intervals in one run; Opening admits 112 of 129 in 11 runs.
With seed 731 and 64 generated events, the actual model produces 1207932 and
3537868 stereo frames respectively. The output checker reconstructs the measured
palette and actual model, checks source/report identities and a latent WFC path,
excludes inadmissible selected spans, and independently verifies every PCM sample.
Opening evidence is `build/pulse-opening-stable.log`. Both WAV/JSON/model sets
replay exactly across compilers (`build/pulse-replay.log`).

Files: `build/corpus/pixel-pulses.wav` and `opening-pulses.wav`.
Pixel SHA256:
`2d87f6dc7cd5e76459f88c88bee92482497e5fd07d4f500736108f40e148b086`.
Opening SHA256:
`43b87906ae00430270144c685adadea558843a8baf4a343d130189be0ccbbbce`.
Native inspections: `build/pixel-pulses-inspect.json`,
`build/opening-pulses-inspect.json`. These rearrange attributed recording slices;
they do not establish original instrumental composition or annotated beat accuracy.

The original onset-event Pixel WAV/model/report and tracked audition/report retain
identical bytes (`build/pulse-regression.log`). Wrong-source report rejection
preserves all three existing outputs (`build/pulse-rejection.log`). The normal
build includes core/WFC fixtures and a controlled tempo-change source smoke:
23 intervals, 16 generated events, 352787 stereo frames, all PCM verified
(`build/pulse-smoke.log`). Build syntax passes. No new full suite or source ZIP
is claimed. [Pulse event contracts and evidence](PULSE-EVENTS.md) retain limits.

Earlier local-track checks pass on both compilers:
`build/beat-track-3.2.2-checked.log`, `build/beat-track-3.3.1-checked.log`.
The native fixture needs no vendor paths; all three laboratory cases and the
tracked audition smoke pass. No owned compiler warnings remain. Source reference
WAVs are unchanged (`build/beat-track-source-regression.log`). The laboratory
evaluates global, raw local and aligned outputs on the same authored interval
with 30 ms tolerance, retaining full output outside that interval in its report.
Regular/polyphonic/tempo-change aligned matches are 24/24, 20/20 and 24/24, with
zero extras and mean errors 0.75, 1 and 0.75 frames. Raw local means are 0.75,
292.4 and 200.625 frames. [Tracking evidence](BEAT-TRACKING.md) records contracts
and limitations, including phase smearing in the separate equal-strength fixture.

Laboratory WAV/JSON, tempo-change audition and Pixel report/audition replay
exactly across compilers (`build/beat-track-replay.log`). Fixed-grid Pixel outputs
also remain identical (`build/beat-track-global-regression.log`). Mixing a global
rank with local-track mode rejects without modifying existing output
(`build/beat-track-rejection.log`). The normal build includes the new native
fixture and tracked audition smoke; syntax validation passes. No fresh full suite
or ZIP snapshot is claimed for this additive unit.

Pixel produces 80 pulse positions in 35 windows, with zero flagged raw joins;
Opening produces 130 in 90 windows with two flags. These counts are execution
evidence, not metrical or beat annotations. Reports are
`build/corpus/pixel-beat-track.json` and `opening-beat-track.json`. Native
inspection is `build/pixel-beat-track-inspect.json`; the Pixel overlay retains
1512000 stereo frames at 44100 Hz, SHA256
`77801c89d0a519f401149a2fd4c887c96c1941de8a13b39973537b46063d8f13`.
The controlled 14-second tempo-change overlay is
`build/3.2.2-i386-win32/beat-track-change-listen.wav`, SHA256
`57de8bbd0316060e9f6a48b31bf38c96d8ef5b02a06bf7cf1f85d266b88a4f00`;
inspection is `build/beat-track-change-inspect.json`.

Earlier constant-grid checkpoint:
The beat fixture, laboratory and native inspection/audition checks
pass on both compilers in `build/beat-3.2.2-checked.log` and
`build/beat-3.3.1-checked.log`. No owned warnings remain; the existing WAVE-unit
unused-variable note remains on development FPC. The focused core fixture needs
no vendor paths. The normal build includes the fixture, three-case laboratory
and polyphonic audition smoke; its syntax check passes. No full suite or package
rerun is claimed for the new unit.

The beat laboratory matches 24/24 authored 120 BPM percussion beats and 20/20
authored polyphonic 96 BPM beats, with no extra grid points at 30 ms tolerance.
Mean errors are 1 and 357.95 frames. Its tempo-change example instead matches
15/24 beats with 11 extras and 323-frame matched error; that failure remains
recorded. Pixel yields 70 and 139.75 BPM candidates, without consulting declared
tempo. Opening yields a weak 47.75 BPM candidate. These recordings are not beat
annotations. [Beat-grid evidence](BEAT-GRIDS.md) gives methods, policies and limits.

Laboratory WAV/JSON, Pixel report/audition and polyphonic smoke replay exactly
across compilers (`build/beat-replay.log`). An unavailable audition rank preserves
both prior outputs (`build/beat-rejection.log`). Moving onset cues into the shared
helper preserves the old Pixel onset report/WAV exactly
(`build/beat-onset-regression.log`). The alternate Pixel rank-1 overlay is
`build/corpus/pixel-beats-fast-listen.wav`, with its report in
`build/corpus/pixel-beats-fast.json` and native inspection in
`build/pixel-beats-fast-inspect.json`. All audible music in that overlay comes
from the source recording; only the timing cues are synthesized.
It retains 1512000 stereo frames at 44100 Hz, SHA256
`042992acf4922381b6f24e9506873a80dff95b9174b04ab24e1f178af701ea6e`.

Earlier event-specific checks:
`build/event-stable-final.log` and `build/event-development-final.log`.
The native core-only event fixture also passes without vendor paths. No owned
compiler warning remains; existing WFC/FCL warnings are unchanged. Pixel's WAV,
model text and JSON reproduce exactly across compilers (`build/event-replay.log`).
A mismatched onset-report source rejects without changing any of the three
outputs (`build/event-rejection.log`). The normal build includes core/WFC fixtures,
the event tool and a published synthesis-source smoke; the script parses and the
smoke passes (`build/event-smoke.log`). No full-suite rerun is claimed for this
additive path. Subsequent package verification is recorded below.

Refreshed FPC 3.2.2 source packages pass in `build/package-inventory-core.log`
and `build/package-inventory-wfc.log`: 50 files / 45 core units, and 161 files /
45 core plus 12 adapters, respectively. Both compile every delivered owned unit
from the extracted ZIP; the core and WFC external examples run. Contents retain
notices and exclude Phanes, binaries and music assets. Existing WFC/FCL warnings
remain; no owned-unit warning was reported.

In `build/package-inventory-wfc/consumer-check/`, copied native onset/event tool
sources and the published-output checker compile against only extracted library
and companion sources. `onsets-run.log` and `onsets-replay.log` confirm the original
374 candidates / 368 resolved locations, with identical Pixel report and audition
WAV bytes. `events-run.log`, `events-verify.log` and `events-replay.log` confirm
128 generated events, 547459 stereo frames, every-sample validation and identical
WAV/JSON/model bytes. The tools/checker are external consumers, not ZIP contents;
the source recording and archive are the existing attributed Pythian corpus.
See [packaging](PACKAGING.md#earlier-onsetevent-package-checkpoint) for commands
and limits. These runs closed the package evidence gap at that earlier checkpoint;
they do not complete the full precursor inventory or establish musical form.

With seed 731 and 128 generated events, Pixel Sprinter's 349 source intervals
produce 77 joint symbols, 245 WFC states and 547459 stereo frames (12.414 s).
Opening Theme's 902 intervals produce 76 symbols, 456 states and 520358 stereo
frames (11.800 s). Published checks verify every source/output interval and PCM
sample, plus independent latent-state reachability. Logs:
`build/pixel-events-verification.log`, `build/opening-events.log`.
[Event learning](EVENT-LEARNING.md) records hashes, replay, source continuity and
the remaining distinction between learned event fragments and musical form.

Earlier finer-grid fixture and tool checks pass on both compilers:
`build/onset-grid-fixture-stable.log`, `build/onset-grid-fixture-development.log`,
`build/onset-grid-stable.log`, `build/onset-grid-development.log` and
`build/onset-grid-lab-stable.log`. Laboratory and audition outputs replay exactly
(`build/onset-grid-replay.log`); earlier wider-grid reports remain identical
(`build/onset-grid-regression.log`). Invalid FFT/source-overwrite requests preserve
prior artifacts (`build/onset-grid-rejection.log`). No new compiler warnings were
reported; the existing WAVE-unit unused-variable note remains on development FPC.
The normal build includes both grids and the audition smoke, and its syntax check
passes. No full-suite rerun is claimed for this scoped change.

Pixel Sprinter yields 374 finer-grid candidates / 368 resolved locations, and
Opening Theme yields 939 / 930. Their reports retain uncertainty; the higher
counts are not annotated accuracy results. The Pixel audition has the source's
1512000 stereo frames at 44100 Hz, SHA256
`7e9c9fee8eed98fc8555d03f9ca8a38594b657137f7eb68ec2d4a5038bf7dbd4`.
Native inspection: `build/pixel-onsets-listen-inspect.json`. See
[onset evidence](ONSETS.md#finer-timing-grid-and-audition-evidence) for controlled
comparisons, real-report paths and the remaining timing limitations.

Earlier onset-localizer checks pass on both compilers:
`build/onset-focused.log`, `build/onset-development.log`,
`build/onset-lab-build.log`, `build/onset-lab.log`,
`build/onset-lab-development.log`, `build/onsets-tool-build.log`,
`build/onsets-smoke.log` and `build/onsets-development.log`.
Five laboratory WAVs and both laboratory/inspection JSON reports replay exactly
across compilers (`build/onset-replay.log`). The full build script now includes
the fixture, laboratory and inspection smoke; its syntax check passes. No full
suite rerun is claimed for this additive core unit. [Onset evidence](ONSETS.md)
records all five cases, including missed/unresolved events, and both real-WAV runs.

Earlier focused ensemble consumer checks pass on both compilers:
`build/ensemble-capacity-validation.log`, `build/ensemble-capacity-development.log`,
`build/ensemble-stream-build.log` and `build/ensemble-stream-development.log`.
The existing music/clock/SMF caller rebuild and checks pass in
`build/ensemble-existing-music.log`. No owned-unit compiler warnings were reported.
The build script includes the new verified demo and parses successfully.

Last full build before the additive consumer and onset unit: `build/chord-stable-full.log`,
terminal exit code 0 on 3.2.2.
At that checkpoint all 43 core units and 11 adapters/callers compile; native fixtures, synthesis tools
and WAV-learning workflows pass. Development 3.3.1 checks for the changed renderer
and bridge pass in `build/chord-development-validation.log`; the prior full
development build is `build/stable-compat-development.log`. No owned-unit compiler
warning was reported in these current checks; existing upstream warnings remain.
[Package evidence](PACKAGING.md) includes the updated 158-file WFC ZIP with all
54 owned units and external consumers, alongside the earlier core-only snapshot.
Those package snapshots predate the onset/event units, event adapter and
ensemble-capacity helper.

[Chord streaming evidence](CHORD-STREAMS.md) includes independent finite-note
sample comparison, delayed release overlap, held phase, zero-sample intervals,
ownership, invalid-call preservation, clock rollback and cancellation. Actual
WFC output agrees for 19851/21606/14404 frames at 44100/48000/32000 Hz. The eight-second
demo is byte-identical on both compilers, SHA256
`0f3876e6748bb4b3fdff94bd07db5f021e96c1b363197e5c9dbc111bb1a91262`.
Its 882-frame delay and bounded 1021-frame writer blocks require no complete clip.

[Learned ensemble evidence](ENSEMBLE-STREAMS.md) adds a 64-cell, eight-bar phrase:
705601 mono frames at 44100 Hz, 13 actual WFC segments, and 17 voice holds crossing
segment boundaries. Every output sample agrees with the precursor. Seven-cell
segments produce identical WAV bytes; stable/development compilers reproduce
both WAV and complete sidecar bytes. The unsatisfiable six-cell guide rejects
before opening outputs and preserves both prior files. Logs:
`build/ensemble-stream-demo.log`, `build/ensemble-stream-replay.log`,
`build/ensemble-stream-rejection.log` and `build/ensemble-stream-inspect.json`.
Output SHA256:
`911586f7f46fe4fa984703ed4b33668fa1e512408c01aeab3f717611e03bd418`.
This is finite symbolic phrase planning and streamed audio, not unbounded
composition or inferred structure from recorded WAVs. Operator listening is open.

| Command / fixture | Observed result |
| --- | --- |
| `./tools/build.ps1` | Full build, native fixtures, renderer and WAV learner passed |
| `./tools/build.ps1 -CoreOnly` | All core units compiled with no vendor search paths; core checks and renderer passed |
| Core PCM fixture | Owning input/output copies, precursor golden WAVE bytes, lossless PCM16 round-trip |
| Decoder boundaries | Every truncation of the golden container rejected; unsupported compression rejected |
| Independent WAV encodings | Hand-authored PCM8/24/32 and float32, odd unknown chunk padding, reordered data/fmt, NaN rejection passed |
| DSP fixture | Fixed oscillator points/tuning, early ADSR release, feedback-delay impulse, filter DC response, noise reset passed |
| Synthesis fixture | Start silence, hard-left pan, retained release tail, nonzero energy, sample-identical replay passed |
| WFC PCM bridge | All 65536 PCM16 values and complete canonical byte stream match the actual WFC implementation |
| Acoustic learning fixture | Analytic A/E dyad and C signal, exact silence, opposite-polarity stereo, RMS/centroid/chroma checks passed |
| WFC learned model | Deterministic palette, observation count, model text round-trip, graph solve and solved-path validation passed |
| Renderer smoke | `synthesis.wav`: 355888 stereo frames at 44100 Hz, about 8.07 seconds |
| WAV learner smoke | Demo recording: 348 analysis frames, 16 acoustic tokens, 36 WFC sequence states; `.wfcs` and `.json` emitted |
| Granular fixture | Independent ramp interpolation, stereo polarity, source-overrun rejection, half-hop Hann gain, boundary fades and explicit overlap mixing passed |
| WFC generation adapter | Caller locks, seed replay, output preservation on failure, and actual recorded-grain reconstruction passed |
| Search-limit fixture | Odd alternating cycle reports a backtrack limit with zero recovery and an exhaustive contradiction with recovery; previous output survives both |
| Streaming WAVE fixture | Stereo layout, short-Finish recovery, bounded writes, partial-sink accounting, reentrancy rejection and sink ownership passed |
| RF64 fixture | Last-RIFF/first-RF64 stereo header boundaries and 64-bit size fields passed without large payload allocation |
| Native provenance | SHA256 known-answer fixture passed; hashes cover exactly the decoded source bytes and match independent platform hashes |
| Published WAV music | Complete Pixel Sprinter loop and Opening Theme recordings decoded, learned and reconstructed into 512-grain stereo outputs; [evidence](WAV-LEARNING.md#published-recording-evidence) |
| Current-writer replay | Both published-recording outputs reproduced identical SHA256 values after writer consolidation |
| Audio inspection | Reconstructed recordings are non-silent, finite, and below unity peak; per-channel metrics retained |
| Exact tempo clock | PPQ remainder across tempo changes, floor/ceiling conversion, extreme integer inputs, grid boundaries and committed-prefix preservation passed |
| Native MIDI codec/import | Independent full-file golden, all truncations, running status, owned opaque bytes, global pairing, explicit FIFO/closure/ignore policies and routing/tempo rejection passed |
| Exact-frame synthesis | Integer first/last gate frames, tempo-crossing notes, retained silence, sub-frame reporting, bounds and replay passed |
| Actual WFC music bridge | Rest/chord/source-coordinate projection, source destruction, fractional timing agreement with WFC rendering and canonical SMF byte parity passed |
| Existing synthesis replay | Full demo SHA256 unchanged after sharing the seconds/frame rendering implementation |
| Precursor MIDI preview | 181 notes from Vocalise № 1 rendered into 35.029 seconds; loss report and measured audio retained in [MIDI evidence](MIDI.md#verification) |
| Shared corpus and archive | Detached centers/measurements, exact binary round-trip, full small-file truncation checks, rehashed invalid versions/counts/NaN, and coordinate/token rejection passed |
| Persisted WFC admission | Orders 1..4, every state and sample-boundary count, valid-but-mismatched model rejection, separate loads and exact token/audio replay passed |
| Published shared corpus | 5353 observations from both complete WAV recordings, 16 shared tokens, 133 WFC states; attribution retained in the archive |
| Shared replay | 512 grains (152 Pixel Sprinter, 360 Opening Theme), 527360 stereo frames; reversed input-file order reproduced identical audio bytes |
| Source mismatch | An unrelated WAV rejected before output writes; the existing remix hash was preserved |
| Activity segmentation | Peak/plateau/refractory rules, silence resumption, forced splits, complete source coverage, irregular grids and an anti-phase stereo impulse passed |
| Continuity planner | Exact forward passage beyond static candidate count, deterministic replay, zero-cost analytic optimum, independently known seam error, invalid-token and work-bound rejection passed |
| WFC activity and locks | Acoustic rhythm tokens match real score rhythm projection; native rhythm model round-trip and caller token locks through grain planning passed |
| Published continuity comparison | 356/511 contiguous links, mean normalized seam error 0.191083 versus 1.110782 baseline; exact replay with reversed source arguments |
| Polynomial oscillators | Six coherent-tone cases show 13.474..36.254 dB alias-power reduction relative to fundamental; zero-frequency, noise recurrence, rejection/replay and renderer option checks passed |
| Sinc resampling | Pass/stop-band sine checks, anti-phase stereo, rational impulse alignment, detached identity, DC extension, empty input, bounds and replay passed |
| Sinc granular playback | 3x playback suppresses a source above the destination Nyquist; unit-rate sample identity retained |
| Native DSP tools | Six-second comparison rendered at 48000 Hz and converted to 264600 frames at 44100 Hz; legacy synthesis hash unchanged |
| Frame automation | Detached curves, hold/linear/geometric interpolation, exact knots, high Int64 coordinates, cents conversion and invalid-candidate preservation passed |
| Tone automation | Note-relative frequency, gain, pan and cutoff curves, filter-history retention, combined pitch preflight and deterministic replay passed |
| Additive partials | Analytic harmonic/inharmonic sums, independent partial amplitudes, Nyquist omission with continuing phase, reset and rejected-call state preservation passed |
| FM/PM | Signed instantaneous FM integration, zero-index carrier identity and seven PM sideband amplitudes checked against an independent Bessel series |
| Oversampled modulation | 4x synthesis plus sinc conversion suppresses the selected folded 22000 Hz sideband while preserving the desired 10000 Hz component |
| Modulation demo | 7.5 seconds, stereo 48000 Hz; measured finite non-silent output, hashes and segment descriptions retained in modulation evidence |
| Shared sources | Seeded waveform parity, additive/FM adapters, independent instances/reset and per-note renderer state passed |
| Sample voices | Detached regions after input destruction, mono/stereo, fractional and multi-wrap loops, sustain release, one-shot exhaustion/rate conversion and rejected-input preservation passed |
| Wavetable sources | Owned coefficients, independent harmonic/cap-crossfade formulas and selected out-of-band harmonic suppression passed |
| Shared renderer | Independent stereo filters, exact-frame note-off path, source work preflight, preserved output on rejection and replay passed |
| Source demo | Five seconds of waveform/additive/FM/wavetable/stereo-sample voices through one tone renderer; legacy synthesis hash unchanged |
| Biquad/EQ | All eight DC/Nyquist/center responses, independent impulse recurrence, reciprocal peaking identity, stereo history preservation and tone-filter integration passed |
| Dynamics and effect chains | Compressor knee/slope/time constants, linked stereo and sidechain, limiter peak/recovery/in-place processing, ownership, poison/reset and split-clip replay passed |
| Effects demo | Six-second dry/processed comparison rendered; float/PCM metrics and unchanged legacy hash recorded in effects evidence |
| Filtered echo | Independent closed-loop quarter-rate impulse equation, stereo independence, input rejection, reset and crossed in-place replay passed |
| Ordered buses | Independently calculated multiple-input/effect/pre/post/master sums, gain time constants, backward-edge rejection and detached frame inputs passed |
| Bus recovery | Downstream poison, preserved outputs, failed partial reset, callback mutation rejection and successful explicit recovery passed |
| Precursor bus layout | Music-return mute suppresses dry/echo together, preserves continuing echo history after unmute and leaves the separate effects input audible |
| Continuous bus rendering | Whole-versus-split sample identity with retained echo tails, work-bound preservation and Single-overflow poisoning passed |
| Bus demo | Six-second five-bus stereo output written in <=1024-frame blocks, finite/non-silent PCM measurements and deterministic output hash recorded |
| Shared playing voice | Offline callers rebuild against one note renderer; source gate delivery, copied automation and all four synthesis/source/effects/bus WAV hashes remain verified |
| Scheduled timeline | Exact starts above 2^53, zero-release note-off/cleanup, active/pending counts, stable IDs and count/work rejection without source allocation passed |
| Future edits and release | Group/pivot cancellation, exact-cursor pending removal and early-attack ADSR release agree with reference schedules while other groups and echo survive |
| Atomic replacement | Invalid/partly constructed candidates preserve original future audio and IDs; replacement at full capacity preserves committed state and matches intended reference audio |
| Scheduler recovery | Failed source construction preserves the queue; source processing failure and callback reentrancy poison it with cursor/output preserved; explicit reset releases owned state |
| Scheduled blocks | Whole/split sample identity, bounded preflight preserving cursor/output and offline signal agreement within Single accumulation rounding passed |
| Scheduled demo | 336000 stereo frames generated directly in <=1024-frame blocks, atomic phrase change at 2.5 s, music release at 4 s, independent effects and retained tails |
| Paired WFC learning | Independent two-recording n-gram/start/end counts, actual rhythm-cell encoding and real model serialization pass |
| Joint constraints | Simultaneous acoustic/activity locks, duplicate-position intersection, unobserved-pair contradiction and preservation of both previous output arrays pass |
| Action-aware grains | Separate bounded action pools retain required onsets at one candidate per pool; every selected source coordinate satisfies both labels |
| Published joint remix | 5353 stored observations produce 30 paired tokens/243 states; 512 selected grains honor onset/sustain locks and independently match all source observations |
| Joint replay and failure | Reversed source arguments reproduce exact WAV bytes; impossible silence request preserves previous WAV/sidecar; prior continuity remix remains byte-identical |
| Joint archive admission | Orders 1..4, all custom activity fields, canonical archive/model bytes and independent paired n-gram counts pass; valid-digest invalid-policy/model attachments reject |
| Saved joint reconstruction | Actual saved model reproduces all 512 published grain records and exact WAV bytes, reusing the stored policy; reversed source arguments replay WAV and metadata identically |
| Joint archive ownership | All success/rejection fixtures free every allocation under isolated heap tracing; failure clears model/policy outputs |
| Integer timing alignment | Exact anchors above 2^53, nearest-cell ties, signed tolerance, overflow and preservation of prior mapping on failure pass |
| Timed WFC projection | Coincident attacks deduplicate, distinct colliding attacks reject, actual WFC locks preserve every requested onset, and contradiction does not relax them |
| Published timed output | Four exact output gates, 173 recorded grain labels, independently checked anchor errors and 88200 exact rest frames pass; reversed sources replay WAV/metadata exactly |
| Shared source binding | Archived SHA256/format/source-count admission reused by both tools; duplicate input rejects, and the existing saved-joint WAV remains byte-identical |
| Tonal extraction | Actual Phanes root/mode selection matches 32 varied-pitch/duration fixtures under the explicit four-quarter-note cap; complete notice retained |
| Pitch-class profiles | Empty/uniform ambiguity, independent triad scores, capped/velocity note weights and overlapping-window coverage/energy weights pass |
| Tonal signal path | Actual FFT analysis of bin-coherent A440 puts over 99.9% of profile weight in A; raw WAV, strict MIDI and stored-corpus inspection run natively |
| Incremental streaming clock | Independent rational oracle, split/whole intervals, snapshot replay, high PPQ, counters above 2^53 and atomic tick/frame overflow rejection pass; actual WFC clock fields match |
| Clock consumer replay | The scheduling demo uses explicit incremental musical intervals; its complete WAV remains byte-identical to the previous frame-step version |
| Player tempo handoff | Rejected tempo preserves clock/IDs/audio; admitted tempo agrees sample-for-sample with independent frame positions, preserving pre-pivot crossing gates, another group and echo |
| Learned sequence stream | Order-3 history across identical public suffixes, caller-array mutation, contradiction/invalid request preservation, retry/reset and a 1601-cell complete path pass |
| Published chunked reconstruction | Twelve chunks, 3072 latent states and source-grain projections independently verified; 3148776 stereo frames rendered without learning or FFT |
| Stream replay and regressions | Reversed source arguments reproduce WAV/metadata exactly; impossible silence in the first or second chunk preserves existing files; the older saved-joint WAV remains byte-identical |

Current focused evidence: `build/voice-bindings-focused.log` and
`build/ensemble-focused.log`, terminal exit code 0. Independent stereo reference
samples verify voice selection, exact tempo-crossing placement and failure
preservation. Actual WFC reconstruction verifies held chord/bass gates, source
identity, template destruction and changed-velocity hold rejection.
`build/ensemble-audio-regression.log` verifies unchanged coupled-layer WAV bytes;
legacy synthesis and scheduling retain their recorded hashes. See
[ensemble synthesis](MIDI.md#independent-synthesis-voices-and-ensemble-frames).

Previous full build: `build/ensemble-full.log`, terminal exit code 0. All forty-two
core units build without vendor paths, all eleven adapters and affected callers
rebuild, and the normal fixtures and native synthesis/WAV learning smokes pass.
This includes the previous turn's coupled-layer checks and example. The first
attempt stopped at the new managed-result failure fixture; after the candidate
publication fix, the focused check and complete build pass. Existing WFC warnings
remain upstream; no authored compiler warning was reported. Stable FPC is now
verified by the later build above. Operator listening and other platforms remain
unverified.

Previous focused change: `build/layers-focused.log` and `build/layers-demo-build.log`,
terminal exit code 0. Forty-two core units remain; the new eleventh adapter does
not change existing core or companion callers. Its four-layer correlation, actual
paths, provider retry, failure preservation and single-layer checks pass. The
16.02-second native demo and complete metadata replay exactly; see
[layer evidence](LAYERS.md), `build/layers-demo.log`, `build/layers-replay.log` and
`build/layers-metrics.json`. Both commands are now in the normal build. Existing
upstream warnings remain; no authored compiler warnings. Operator listening and
other compiler/platform targets remain unverified.

Earlier full build: `build/passage-full.log`,
terminal exit code 0. Forty-two core
units compile without vendor source paths; all existing fixtures and native tool
smokes pass. The new passage fixture runs and the native passage tool compiles.
The optional published checker was compiled separately in
`build/passage-output-build.log` and is included in future full builds.
No authored compiler warnings; existing upstream WFC warnings remain.
Published source/model/path/all-sample checks pass in
`build/passage-published-validation.log`. Exact three-file replay and rejection
preservation pass; [passage evidence](PASSAGES.md) records the command, artifact,
source clock, output hash and remaining musical limitations. Operator listening
and source frame-zero downbeat alignment remain unverified.

Earlier full build: `build/resample-stream-full.log`, terminal exit code 0.
Forty-one core units and ten adapters are present. Core fixtures build without
vendor paths and all existing adapter/tool checks pass. The new streaming
resampler fixture covers block identity, exact length/endpoints, bounded input
reads, stereo, independent pass/stop-band checks, invalid PCM, reader failure and
swallowed reentrancy. No authored compiler warning was reported.
`build/resample-stream-audio-regression.log` verifies unchanged default scheduling
and existing offline sinc-conversion WAVs. The new direct 44100 Hz scheduled
output has 308700 stereo frames (7 s), SHA256
`1f3113cf558d27d4d55a345ab5f93408b3d91537b7db3f073a2f5b0b2787e564`.
See [continuous conversion](DSP.md#continuous-conversion),
`build/resample-stream-demo.log` and `build/resample-stream-metrics.json`.
Operator listening and real-time device deadlines remain unverified.

Earlier full build: `build/stream-full-validation.log`, terminal exit code 0. Forty
standalone core units and ten WFC adapter units are present. All build fixtures
and existing tool smokes pass, including the new sequence-stream fixture and
the joint-constraint helper's existing callers. WFC unreachable-code/range
warnings remain upstream; no authored warning was reported.
Published stream details and commands are in [learned streams](LEARNED-STREAMS.md).
Focused evidence: `build/sequence-stream-validation.log`,
`build/stream-published-validation.log`, `build/corpus/shared-stream.log`,
`shared-stream-replay.log`, `shared-stream-rejection.log`,
`shared-stream-late-rejection.log`,
`shared-stream-inspect.json` and `saved-stream-regression.log`.
Output SHA256:
`0806667b5e75520198f221b326bbcc8c7b3f60447648090fc763239f36207104`.
Operator listening is unverified; graph chunking is not unbounded audio output
or proof of musical form/beat quality.

Earlier full build: `build/clock-validation.log`, terminal exit code 0. All forty
core units and nine adapters compile; native and actual WFC clock fixtures pass.
The clock core fixture builds without vendor search paths. Existing upstream
warnings remain; no authored compiler warnings were reported. The later focused
scheduler integration check passes in `build/player-tempo-validation.log`.
The unchanged seven-second demo is verified by `fc /b` and SHA256 in
`build/clock-audio-regression.log`:
`e2aba881180f4e8e36e678f5a7c90e635a91c85c82432c7065c65d1f06c21798`.
See [incremental timing](MIDI.md#incremental-streaming-clock) and the complete
[preview/player dispositions](PROVENANCE.md#preview-disposition).

Latest core-only build: `build/tonal-validation.log`; all forty core units compile
without vendor paths and the native checks/MIDI/WAV smokes pass. Direct comparison
with actual Phanes runs only in an isolated optional fixture build:
`build/tonal-precursor-validation.log`. Native inspection of both attributed
recordings is in `build/corpus/tonal-duration.json` and `tonal-energy.json`;
the raw Pixel Sprinter path is `build/corpus/tonal-pixel-wave.json`.
The different close-ranked outcomes under weighting are reported as heuristic
fits, without annotated key-accuracy claims. See [tonal extraction](TONAL.md).
No authored compiler warnings; the optional precursor build retains one existing
Phanes managed-variable warning. No WFC code changed in this checkpoint.

Earlier full build log: `build/timing-validation.log`; all thirty-nine core
units compile without vendor paths and nine adapters pass native/WFC integration.
Both grid and MIDI timed-remix smokes pass. Final recorded-music checks:
`build/timed-published-validation.log`; core arithmetic:
`build/alignment-focused-validation.log`; WFC locks/collisions:
`build/timed-wfc-focused-validation.log`. Final tool rebuild and render-policy
metadata: `build/timed-remix-tool.log`. The four-second WAV has 173 learned
grains, four onset constraints and 88200 exact rest frames. Timing/source
rejections preserve existing outputs. Shared source-binding extraction retains
the earlier saved-joint WAV exactly (`build/source-helper-regression.log`).
See [timed-generation evidence](TIMED-LEARNING.md). No authored compiler warnings.
Operator listening, true source beat/onset accuracy and portability remain open.

Earlier full build log: `build/joint-archive-validation.log`; all thirty-eight
core units compile without vendor paths and eight adapters pass native/WFC
integration. New prepare/inspect/saved-remix commands pass. Focused archive
checks: `build/joint-archive-focused-validation.log`; final published model,
policy and complete source-grain replay checks:
`build/joint-archive-published-validation.log`. Isolated heap tracing frees
44324 allocated blocks with zero unfreed blocks:
`build/joint-archive-ownership-validation.log`. Recorded-music saved generation
matches the prior WAV byte-for-byte; a silence contradiction preserves outputs.
The original acoustic archive is unchanged. See [joint archive evidence](JOINT-ARCHIVE.md).
No authored compiler warnings. Full goal, operator listening and portability
verification remain open.

Earlier full build log: `build/articulation-validation.log`; all thirty-eight core
units compile without vendor paths, both articulation CLI modes run, and existing
native/WFC learning and reconstruction checks pass. Final focused signal and
published-sample checks: `build/articulation-focused-validation.log`; final tool
rebuild: `build/articulation-tool-validation.log`. Every sample in the eight-second
recorded-music output matches an independent PCM calculation, including 176400
exact rest frames. WAV and metadata replay identically; an invalid hold pattern
preserves both existing files. See [articulation evidence](ARTICULATION.md).
No authored compiler warnings.

Earlier full build log: `build/joint-validation.log`; all thirty-seven core
units compile without vendor paths before actual WFC/MIDI/corpus/scheduler
checks and both ordinary/joint reconstruction smokes pass.
Final focused and published-coordinate checks:
`build/joint-focused-validation.log`. Published audio, model/coordinate mapping,
replay, contradiction log and metrics are under `build/corpus/shared-joint*`.
The saved corpus remains unchanged. [Joint evidence](JOINT.md) records the
derived model, source-window semantics, listening artifact and limitations.
No authored compiler warnings. Operator listening and annotated beat/onset
accuracy remain unverified.

Earlier full build log: `build/schedule-validation.log`; all thirty-seven core
units compile without vendor paths before actual WFC/MIDI/corpus checks and WAV
learning/remix smokes pass. Final replacement/recovery fixture:
`build/schedule-focused-validation.log`; final demo:
`build/schedule-demo.log`; audio metrics: `build/schedule-metrics.json`.
The existing resampling fixture caught a stored-Double versus x87 quotient
comparison in the new prepared-voice check. Comparing like precision fixed it;
the focused regression log is `build/schedule-refactor-regression.log`, and
the subsequent full build passed. No authored compiler warnings.
The focused scheduler fixture also passes with isolated heap tracing:
`build/schedule-ownership-validation.log`, 416 allocated/freed blocks,
zero unfreed blocks, including failed candidate construction and replacement.
[Scheduling contracts and evidence](SCHEDULING.md) record ownership, absolute
frames, capacity/work policy, candidate publication, recovery and listening.
Legacy synthesis, sources, effects and buses retain their earlier SHA256 values.
Operator listening and device timing remain unverified.

Earlier full build log: `build/bus-validation.log`; all thirty-six core units
compile without vendor paths before actual WFC fixtures and WAV learning/remix
smokes pass. Final focused bus checks: `build/bus-focused-validation.log`,
including return-mute history and callback reentrancy. Demo compile/render:
`build/bus-demo.log`; PCM metrics: `build/bus-metrics.json`.
No authored warnings. [Bus contracts and evidence](BUSES.md) record ownership,
topology, failure recovery, filtered feedback and the six-second listening file.
Legacy synthesis and the effects demo retain their prior SHA256 values.
Operator listening and real-time device execution remain unverified.

Earlier full build log: `build/effects-validation.log`; all thirty-four core
units compile without vendor paths and actual WFC learning/reconstruction checks
pass. Final failure/overflow/in-place checks:
`build/effects-focused-validation.log`; demo: `build/effects-demo.log`;
metrics: `build/effects-metrics.json`. [Effects evidence](EFFECTS.md) records
biquad equations, compressor/limiter policy, chain recovery and the listening
comparison. This turn rechecked the logs and reproduced the same effects hash.

Earlier full build log: `build/source-validation.log`; all thirty-one core units
compile without vendor paths, and actual WFC checks and WAV learning/remix
smokes pass. Final focused source checks: `build/source-focused-validation.log`,
including direct exact-gate delivery and source-destruction observation.
One-shot/rate cases also pass in the full build.
Source demo measurements: `build/source-metrics.json`.
No authored compiler warnings. [Source contracts and evidence](SOURCES.md)
record ownership, region/loop semantics, harmonic limits, weighted work and audio.
Legacy synthesis is byte-identical. Operator listening remains unverified.

Earlier full build log: `build/modulation-validation.log`; its core phase compiles
all twenty-seven units without vendor paths, followed by actual WFC checks and
learning/remix smokes. Final per-partial amplitude modulation and independent
series checks: `build/modulation-focused-validation.log`. Final demo rebuild:
`build/modulation-demo.log`; measurements: `build/modulation-metrics.json`.
No authored compiler warnings. [Modulation evidence](MODULATION.md) records
ownership, bounds, precursor dispositions, spectral checks and the listening artifact.
Legacy synthesis remains byte-identical. Operator listening quality is unverified.

Earlier full build log: `build/dsp-validation.log`; its core phase compiles all
twenty-four units with no vendor search paths. All actual WFC fixtures and
learning/remix smokes passed. Additional synth-option, empty-input and budget
checks passed in `build/dsp-focused-validation.log`. No authored compiler
warnings. [DSP contracts and evidence](DSP.md) record spectral measurements,
artifact hashes, interpolation boundaries and the unverified listening gate.
The longer sinc kernel resolved the initial 7 kHz passband attenuation failure
without relaxing the fixture threshold.

Earlier full build log: `build/activity-validation.log`; core-only rebuild:
`build/activity-core-build.log`. All twenty-three core units compiled without
vendor search paths. Focused checks: `build/activity-core-validation.log` and
`build/activity-wfc-validation.log`. Final tool compile/export after removing
an unreachable enum branch and adding onset-window metadata:
`build/activity-final-tool.log`. Current authored units have no warnings;
the adapter build retains existing WFC unreachable-code warnings.
Published comparison and derived rhythm model: [activity evidence](ACTIVITY.md#verification-and-recorded-evidence).

Earlier full build log: `build/corpus-validation.log`; core-only rebuild:
`build/corpus-core-build.log`. All twenty-one core units compiled without vendor
search paths. Focused logs: `build/corpus-core-validation.log` and
`build/corpus-wfc-validation.log`. Published shared archive, output, hashes,
metrics and logs: [corpus evidence](CORPUS.md#verification-and-current-limits).

Earlier full build log: `build/music-validation.log`; subsequent tempo-allocation
and sub-frame checks: `build/music-focused-validation.log`. Earlier focused logs:
`build/reconstruction-validation.log`, `build/streaming-validation.log`.
The prior MIDI checkpoint's core-only rebuild is `build/music-core-validation.log`;
its eighteen core units compiled without vendor search paths and no warnings.
The precursor preview report is `build/midi-mutopia-validation.log`;
its output hash remained identical after the importer allocation change.
Artifacts: `build/3.3.1-i386-win32/`; published recordings, outputs and mappings:
`build/corpus/`. Core compilation has no warnings. Adapter builds
retain upstream WFC unreachable-code warnings; dependency source was preserved.

Not verified: operator listening quality, broad real-world WAV corpus coverage,
other OS/CPU targets, browser targets, CI execution, published release delivery,
cross-platform floating-point parity. Compilation and analytic fixtures do not
prove these. The subsequent reference audit separately establishes source independence.
The two external corpus runs are integration evidence, not a general-quality
gate. Full RF64 payload playback and atomic artifact publication are unverified.

## Remaining delivery gates

Historical scope record: the following list predates later implementation and
acceptance decisions. Use the [active backlog](MILESTONES.md#active-backlog) for
current remaining work, dependencies and supported scope.

1. **Precursor source audit — complete.** Shared timing, MIDI handling,
   scheduling, buses and corpus extraction in WFC/Phanes have dispositions. Sequential PCM/RF64
   writing, exact clocks, raw MIDI and explicit note projection are implemented
   and checked. Native bus routing, gain lifecycle and filtered echo are now
   extracted and checked. Native scheduled-voice admission, release, future
   cancellation and atomic replacement are now implemented. The named
   score/text/MIDI and ensemble-support source audit is now reconciled in
   [precursor boundaries](PRECURSOR-BOUNDARIES.md#completed-source-inventory).
   The current artifact/notice/independence audit has passed and the temporary
   reference is removed; retained provenance records the completed extraction.
   Complete preview/player unit reviews now assign browser/application policies
   explicitly; actual WFC incremental clock parity and native tempo publication
   are checked. Phanes duration histograms and diatonic fits are now extracted
   and checked against the actual precursor; fixed excerpt/density/degree-remap
   policies remain with the application. Further tonal analysis may extend this
   explicit heuristic without treating its current results as verified keys;
   browser device-context lifecycle belongs to a host adapter. The complete
   Phanes track unit now has a disposition; its authored phase/shape policies
   do not define core synthesis or learned WAV structure.
   Reusable implementations are native; application and constraint-specific
   behavior retain explicit companion/application dispositions.
2. **Complete fundamental synthesis.** Polynomial oscillator correction,
   bounded offline sinc conversion, immutable frame automation and additive/FM/PM
   building blocks are implemented and measured. Oversampled PM has focused
   spectral evidence. Shared source factories now add harmonic-limited wavetable
   and pitched sample voices, explicit loops and per-note source lifetime.
   Biquad/EQ, linked dynamics, serial effect chains, ordered bus sends and
   filtered echo are implemented with native listening examples.
   Keyboard/velocity instrument layers, periodic/affine controls, stereo
   modulated delay and reverberation now extend those fundamentals, with
   extracted-package consumer evidence.
   Extend modulation routing, sample/wavetable controls and bandwidth management.
   Continuous fixed-rate conversion now retains
   bounded filter history, exact rational source position and explicit EOF.
   Streaming note lifecycle is now
   implemented with preserved committed voices and tails.
   Provide small audible examples and
   meaningful boundary/signal checks for the implemented contracts. Granular
   rendering includes optional anti-aliased rate conversion; further sample
   controls, dynamic-rate conversion and device integration remain outstanding.
3. **Complete WAV music learning.** Persisted validated palette/corpus artifacts,
   exact source hashes, attribution and multiple same-format recordings with a
   shared vocabulary are implemented. Bounded onset candidates, complete temporal
   partitions and a real WFC rhythm vocabulary are now present. Joint observed
   acoustic/activity generation and matching grain selection are implemented.
   Generalize
   musical/timbral
   representations that cooperate with the MIDI path. Broaden validation on attributable
   real music recordings, including polyphony, drums, silence and stereo.
4. **Complete the WFC audio loop.** The initial path now generates through
   actual WFC constraints, preserves locks/budgets and failure distinctions,
   and reconstructs recorded WAV grains. Inspection/listening tools are present.
   Persisted acoustic-only and joint inputs generate without relearning.
   Joint archives independently admit all paired observations under the exact
   stored activity policy and reuse that policy in source-grain planning.
   The original derived-joint command remains available. Extend beyond one-shot
   fragments with usable musical controls, longer-form continuity and operator
   listening evaluation. The optional beam planner now improves measured source
   continuity. Saved context profiles now select key and tempo independently
   through repeated derivation, retaining complete parents. Their controlled
   dependent gate policy still needs richer voice/joint contracts. Explicit WAV
   tonal admission now supplies saved providers; local key and measured tempo
   admission remain open. The beam planner continues to preserve
   every requested token. Joint acoustic/activity
   locks now preserve observed source labels. Explicit PPQ/MIDI output articulation
   now guarantees output rests after overlap mixing. Aligning measured source
   onset candidates to explicit gate starts now uses bounded integer mapping,
   actual WFC locks and reported quantization errors. True source beat/transient
   accuracy and longer-form controls remain open. Learned generation now retains
   exact latent history through bounded chunks and validates the combined path
   before one continuous grain plan/render. This advances beyond the single
   graph extent without introducing a second learner or claiming musical form.
   Do not equate spectral
   clustering with transcription or original composition.
5. **Portability and delivery.** The preceding 58-core / 17-adapter full workflow
   passes on FPC 3.2.2 i386-win32. Its source ZIPs compile all owned
   units and run delivered core/WFC examples on FPC 3.2.2 and 3.3.1 i386-win32.
   Verify the supported clean Git checkout build and remote dependency pins,
   add proportionate CI and establish the remaining supported platform evidence.
6. **Phanes removal gate — passed.** The temporary reference has been removed
   after the audit below. WFC remains the pinned companion.

These gates retain the full requested end state. Passing the initial core and
learner fixtures does not close them.

## Phanes removal gate

- Complete the precursor inventory with justified dispositions.
- Prove equivalent intended behavior where extracting existing logic; document
  deliberate synthesis differences instead of implying browser sound parity.
- Demonstrate native library and WFC consumer flows without Phanes source or
  assets, including the expanded learner and listening workflow.
- Preserve necessary notices and provenance outside the removed reference.
- Remove the Phanes gitlink and `.gitmodules` entry together only after those
  checks. WFC remains a pinned submodule.

Completed: the [removal audit](REFERENCE-REMOVAL.md) reconciles the full named
inventory, applicable notices, earlier extraction comparisons and deliberate DSP
differences with current independent 52-unit package consumers. Actual WAV-event
learning and voice/chord-MIDI replay pass. The final actual Phanes tonal comparison
was captured into ordinary native regression constants before removal. Its gitlink,
`.gitmodules` stanza and temporary worktree are removed together; remaining
WFC/Athena submodules are unchanged. Broader project goals are still open.

## Next bounded action

Historical planning context follows. The current next work is owned by
[First work to schedule](MILESTONES.md#first-work-to-schedule); completed mechanisms
mentioned below must not be scheduled again from this older list.

Prioritize the [current WAV-style outcome milestones](MILESTONES.md#next-work-five-outcome-milestones).
The user requested larger progressive goals rather than a series of increments
whose combined contribution is below ten percentage points. Reuse the primitives
below as part of that integrated outcome, with explicit learned-versus-authored
evidence and a second saved derivation. Do not count the provisional percentage
allocation as proof of completion.

The preceding 58-unit / 17-adapter source packages pass extracted consumer
verification on both supported compiler versions. The precursor inventory and
Phanes removal gate are complete; preserve their evidence and the WFC boundary.
Do not reopen completed extraction or package work without a concrete change.

Explicit WAV tonal selection now feeds typed key/tempo profiles with a declared
constant clock. Those providers now feed the independent-voice operator through
an explicit authored arrangement policy. Next extend measured local timing
admission and WAV-derived voice behavior using existing pulse/event evidence,
exact clocks and source hashes. Keep acceptance, unknown values and scope
explicit. Saved onset styles already support weighted independent source samples,
repeated derivation and selective onset edits preserving accepted key/tempo.
Measured joint onset/intensity now supplies another supported style dimension.
Next integrate richer admitted event/run scopes and measured voice/pitch relationships into
that reusable path. Extend semantic layers and necessary relationships without
treating acoustic palette indices as notes or marginal combinations as observed
joint musical evidence. Fixed-model named sessions provide a control mechanism;
they do not supply the missing learned voice content.
The periodic pitch primitive and weighted pitch-run adapter now supply a tested
monophonic route to measured note content, now integrated with saved layered
styles, source scopes and explicit unknown handling. Matching dimension weights
now retain pitch/onset relationships through saved joint runs and explicit coupled
generation. Dense overlapping measurements now add duration models retained in
saved styles and consumed by actual key/tempo/performance passes. Next connect
duration-driven accompaniment to the voice stack, validate recorded instruments
and extend note-onset ownership while preserving the requirement for
mixed-recording voice relationships. The zero-candidate
Pixel inspection is a concrete limit, not a reason to silently loosen admission
or substitute authored melody while claiming extraction.

Evaluate onset/pulse admission against attributable recorded-music annotations,
including tempo changes and uncertain gaps. Source-onset alignment does not
establish beat identity; internal support counts do not replace annotated
accuracy, and unknown downbeats stay unknown. Integrate useful admitted events
with passage/phrase controls while retaining exact source coordinates and
independent recording/run boundaries. The current bar example reuses source
content and an authored ending; it is not evidence of learned large-scale musical structure.

Continue fundamental synthesis expansion through existing source, automation,
effect and bus contracts. Keyboard/velocity instrument layers, periodic/affine
controls, fractional/modulated delay, reverb and bounded WAV analysis are now
delivered. Further modulation/sample controls and bandwidth management should
reuse these primitives. Adaptive-rate conversion, automatic tail policy and
device callbacks remain distinct contracts; committed voices and bus tails
must preserve their existing state guarantees.

Clean Git checkout verification, proportionate CI, additional target evidence
and atomic artifact replacement remain delivery work. Source snapshots and
local checked builds do not establish those outcomes. Preserve the explicit
scope of each validation checkpoint; broader musical admission and weighted
voice/joint style composition remain open beyond the delivered onset profiles.

## MAPS whole-archive integrity stop — 2026-09-24

For NS-3_notes_05 criterion 3, the frozen MAPS v3 continuation completed one
HTTP 206 transfer from an unverified 209,244,160-byte prefix to the declared
2,661,240,101-byte length. Pascal's whole-file MD5 was
`47054c03b6e52db826902340d7aa5ea6`, not the publisher's
`a1c8c9945a2c605f62484b80cfa20cf4`; a second Pascal buffer size agreed.
The exact [source result](PRESENCE.md#maps-whole-archive-integrity-route-stopped--2026-09-24)
records SHA-256, transfer and QA. No ZIP directory was parsed and no MIDI/WAV
member or scorer was opened.
The integrity route is stopped without acoustic evidence or task credit. The
prepared Pascal MIDI and sparse WAV tools passed Salty Boi's source-free
synthetic checks after one pre-execution extraction-hash fix. Current overall
credit stays 68.65. The next useful development checkpoint is a genuinely
new two-part WFC render, explicitly scoped as diagnostic rather than accepted
recorded-note learning.

## Two-part note-event gap — 2026-09-24

The published-note two-part control was coherent to the user but an exact
replay. One frozen private Pascal diagnostic tried 1,024 joint flute/violin
active-pitch cells as a WFC training path, with fixed score hashes, seed,
quantization, novelty and activity gates. Stable FPC 3.2.2 Win32 compilation
passed; the sole run stopped in 1,349 ms before model generation because the
decoded training grid displaced a source gate by 40,424 frames versus the
predeclared 15-ms limit. No generated WAV exists and no listener judgment was
requested. The ignored `build/score-wfc-two-part/PLAN.md`, `RESULT.md`, source
and log preserve the attempt. Dense sampled pitch sets cannot reliably retain
the ownership of repeated attacks; retuning this grid is stopped.
Salty Boi confirmed the structural cause from bound flute rows 7–8: both map
to MIDI 79, with the first ending exactly when the second begins at 4.110 s.
The grid sees a continuous `{79}` state and merges the two gates, placing the
second onset 40,424 frames after the decoded gate start. Rows 15–16 repeat
the pattern. The private survival comparator can count a merged gate for more
than one source row, but the displacement gate rejects this case first. The
frozen plan, source and Notes hashes and sole exit were checked; no WFC path
or WAV was created.

The existing WFC acoustic-event token has an acoustic palette index, duration
class and onset flag but no explicit part ID or inter-onset delta. It cannot
directly represent two-part note gates without conflating acoustic clusters
with pitches. The task-flow gap process therefore split the original 4 unearned
NS-4_integration_01 goal points into 2 for a new maintained
[NS-4_note-events_01](TODO/DONE/NS-4_note-events_01.md) adapter and 2 retained for
[NS-4_integration_01](TODO/NS-4_integration_01.md). The new task owns joint
onset bundles, per-note duration and part, onset deltas, retriggers, exact
round-trip and bounded WFC generation. This is a changed core deliverable,
not another threshold/seed variant. The catalog now has 37 open tasks; overall
credit remains 68.65.

## Joint note-event codec first batch — 2026-09-24

The new maintained `pythian.wfc.note.events` adapter encodes exact one-tick
joint onset bundles with two part identities, every note-gate field, explicit
inter-onset deltas, PPQ/tempo and phrase extent. It round-trips retriggers,
simultaneous starts, unequal ends, overlap, rest and an all-silence phrase;
malformed tokens do not replace an existing result. A focused Pascal test is
now in the normal WFC build path. Ticket Guy's checked FPC 3.2.2 Win32/Win64
runs and Salty Boi's independent checked runs both pass with zero unfreed
blocks. Salty Boi also confirmed canonical token replay and the build-hook
placement. The frozen first-batch plan and logs are ignored under
`build/note-event-adapter/`. This establishes the exact event representation
that the dense pitch-set grid lacked. At this checkpoint it had not run a WFC
solve or made new music, so NS-4_note-events_01 and the 68.65% total remained
open. The next action was a bounded joint WFC generation consumer with a
substantial native two-part listening checkpoint; the following entries record
that work and its still-pending listener verdict.

The source-bound feasibility inventory then found that all 187 exact Spring
joint-event tokens are distinct, with zero order-1 or order-2 exact-token
branching. Direct WFC learning over those full tokens would be an exact-fragment
replay, so one private bounded diagnostic is frozen under
`build/note-event-adapter/GENERATION-PLAN.md`: WFC may choose part-constrained
pitches while the source's 187 event slots, durations, onset times and tempo
stay fixed. This will test the note-event path and audible pitch coherence,
not new rhythmic composition or recorded-WAV inference. The inventory itself
earned no task or goal credit.

One frozen part-constrained order-2 WFC candidate then passed on checked
FPC 3.2.2 Win64: 187 score-timed note slots survived, 78 flute and 65 violin
pitches changed, 135 cross-part overlaps remained, and the deterministic
pitch-token replay matched. The 30-second stereo PCM16 native WAV has SHA-256
`f6c3fc7ad9fc24822e4dc75f038fe74247e60f4e968f3ed88083eb2d6f89c4ee`.
Source-free controls and hash-bound preparation passed checked Win32/Win64;
the candidate and later audit run reported zero heap leaks. Initial final QA
was correctly withheld because the report omitted required ordered event
evidence. A separately frozen audit-only reproduction matched the exact
original token digest, saved both event ledgers and all 187 pitch tokens,
and did not modify or rerender the WAV. Salty Boi independently verified
the tokens, event fields, clock/extent and unchanged audio hash, then passed
the engineering QA. The numbered mobile listening clip is now available
for the user's musical verdict. Until that verdict, NS-4_note-events_01 is
open and overall credit remains 68.65. This remains score-timed pitch
generation, not learned recording inference or new rhythmic composition.

The companion maintained `pythian.wfc.note.events.generation` path now trains
open-boundary WFC on exact joint onset bundles from multiple two-part sequences.
It rejects mixed source clocks and part identities, retains the training
PPQ/tempo with the model, constrains zero-delta tokens to the first output
position and decodes full generated paths transactionally. A source-free
order-2/seed-731 two-sample control generated a new six-bundle/seven-gate
joint event path with a retrigger, rest, overlap and unequal durations; same
seed replay matched. An incompatible tempo map failed before model publication,
and a fixed solve against an undersized extent left the caller's prior output
unchanged. Salty Boi independently passed checked stable FPC 3.2.2 Win32 and
Win64 focused runs with zero leaks and verified the non-CoreOnly build hook.
Earlier fixture assumptions about overlength contradiction were stopped and
recorded in ignored `build/note-event-adapter/maintained-generation-notes.txt`;
they did not change the generator seed or use source audio. This is an accepted
engineering substep within the still-open task; the substantial private WAV
still needs the user's verdict. Overall credit remains 68.65.

The listener then reviewed the 30-second pitch-generated clip and heard an
improvement over the earlier stumbling preview, but also heard popping during
playback and notes that seemed to overlap. "Clipping" in this feedback means
audible pops, not a claim that the PCM reached full scale. The generated clip
therefore has not passed the listening checkpoint; NS-4_note-events_01 remains
open and overall credit remains 68.65. A bound read-only Pascal comparison in
ignored `build/note-event-adapter/` verified the four source/generated event
and WAV hashes and found no PCM samples near full scale. The ten largest
adjacent-sample jumps in each WAV land exactly at authored note ends while
another note continues. Mean local maxima at 135 overlapping note ends were
521.541 PCM counts in the generated clip and 575.919 in the exact-score
control, versus 65.365 and 63.904 at 52 isolated ends. Salty Boi independently
verified the hash bindings, boundary mapping and report wording. This supports
a shared render-policy hypothesis; it does not prove which pops the user heard.
A single 5-ms per-voice release trial is frozen privately, with no WFC or
event changes and no new listening claim yet.

That one render-policy trial then passed. Keeping the 187 source/generated
event slots, 78 flute and 65 violin pitch changes, 44-frame post-mix
articulation and all other controls fixed, the private Pascal renderer changed
only each synth voice's release from zero to 5 ms. Its two-note source-free
control showed the ending voice decaying under a continuing voice while the
continuing voice matched alone exactly. In both checked FPC 3.2.2 Win32 and
Win64, the 30-second stereo PCM16 generated WAV had SHA-256
`82e2e1ad275fbb4517c37fa0b44dc8ff9b6926ae80b4aa29b506f87bd5a62c0a`
and the corresponding score control had SHA-256
`7f52b1fa5ec09840ad713e7184098b3f724d74b94832fd7aa95e75567aafa26f`.
Mean local maximum adjacent-sample change around the 135 overlapping note
ends fell 78.319% in the candidate and 80.248% in the control, above the
frozen 50% gate; neither new top-ten jump set contains an overlapping-end
step. No full-scale PCM samples or heap leaks were found. Salty Boi
independently verified the plan, hashes, events, source-free control, policy
delta, checked runs and cross-target replay. An initial input check stopped
before rendering because a hash had been transcribed incorrectly in the plan;
the exact file hash was corrected. A later diagnostic pass was stopped after
writing interim WAVs because its overlap lookup was needlessly quadratic;
only the analysis loop changed before the successful rerun. Neither stop
changed the frozen audio policy or gates. The QA-passed candidate is served
as numbered mobile feedback `2.wav`; the listening verdict remains pending,
so NS-4_note-events_01 stays open at 68.65 overall credit.

The packaged two-voice notes example had the same avoidable hard note-end cut:
both authored voices used zero release while the other voice could continue.
An ignored frozen plan under `build/notes-example-release/` bound one maintenance
change to 5 ms per-voice release, leaving MIDI, gate times, pitches, velocity,
gain and pan fixed. Checked stable FPC 3.2.2 Win32/Win64 example replay passed
exact MIDI/audio roundtrip with zero heap leaks and identical output hashes.
The MIDI SHA-256 remains
`55b9895e53d73f4134cffbdb1f207da89063af6b332de2ad623a759716287ecb`;
the new 97,241-frame stereo WAV SHA-256 is
`b32c0ee15ef705fcaa364c0ba4fbb3ac82c94636715aa6902c400a08b275a76c`.
At three authored note ends, the mean maximum adjacent-sample delta fell from
0.07197062 to 0.00151571 (97.9%), passing the frozen quarter-baseline gate.
Salty Boi independently reproduced the checked runs, hashes and boundary
measurements. This fixes the delivered example's render setting; it does not
substitute for the user's verdict on the separate 30-second generated clip or
close NS-4_note-events_01. Overall credit remains 68.65.

A bounded authored-control full-event check under ignored
`build/joint-event-control/` tested whether maintained joint-event WFC could
make a substantial new two-part sequence without replaying Spring's published
timing. Three source-free 16-bar C/Am/F/G variants supplied exact 64-bundle
training samples; one frozen order-2 seed-731 solve generated 64 bundles and a
32-second native WAV. Salty Boi independently passed checked FPC 3.2.2
Win32/Win64: generated token SHA-256
`60be651569ee5604c48329609868416b7cfefa38cffed8fb8bf63182f9eea5ff`,
WAV SHA-256
`92c32cd7c2f2c7110f5639d0c2d6d0c84a3df1e0aa18ed2b9345ca6e5f569622`,
15 complete bars differing from each complete source, all three source
variants, 59 melody/37 bass gates, 1,411,200 stereo frames and zero leaks.
The first novelty audit counted only the two variable tokens per bar; a
four-token audit repair preserved both hashes. A focused Pascal scan found
maximum adjacent-frame delta 0.00439453 near the opening attack; it cannot
establish audible quality. An initial index-relative musical check found
30/59 melody and 20/37 bass notes outside the chord authored for that bar
position. That count alone could reflect a coherent new chord order. A frozen
audit-only replay therefore compared complete generated bars to every source
bar: 6/16 match one exactly; four of the ten unmatched bars retain their own
beat-0 bass root and melody triad; six combine pitch classes outside their own
inferred source triad. Salty Boi independently reproduced the event audit on
checked Win64 with identical hashes and zero leaks. The report distinguishes
the passing structural/render gate from `harmony_audit=STOP_PRIVATE`. This
candidate stays private under the authored one-chord-per-bar control. It is
not a WAV-learning or style result, has no listener verdict, and earns no credit.
Await the separate QA-passed clip-2 listener verdict before another musical
generation batch; if needed, define a context-aware hypothesis with prospective
gates. NS-4_note-events_01 remains open and total credit stays 68.65.

A read-only review of the maintained joint-event adapter explains the private
full-event result's contract limit. `LearnJointNoteEventWfcModel` learns an open
sequence from individual onset bundles; `BuildPositionConstraints` only removes
zero-delta tokens after the first generated position. Neither the learned model
nor the generation call carries a bar, chord or key identity. The six bars that
violate their own inferred triad are compatible with that unconditioned model;
the exact event codec has no evidence of changing notes. If full-event harmonic
coherence is pursued after the clip-2 listener checkpoint, use an explicit
source-bound context or grouping contract with frozen gates. Merely increasing
sequence order does not enforce the authored one-chord-per-bar condition. This
review changed no code, candidate, audio, task credit or listening status.

The user then reviewed the numbered mobile feedback and reported no more
popping and a more music-like result, while still judging it short of a coherent
song. A second numbered observation described better perceived harmonization
with some conflicting notes and beats. The mapping of items 1 and 2 to the two
served filenames is under clarification, so this is a paired-review report,
not a file-specific comparison yet. The revised 5-ms release changed neither
the generated pitches nor authored event timing; it cannot be credited with a
new harmonic decision. The audible-pop concern has improved, but musical
coherence remains an open listener gate in NS-4_note-events_01. The stopped
unconditioned full-event candidate stays private, and overall credit remains
68.65. The next bounded generation hypothesis must use explicit harmony
context and score both novelty and within-context relationships before a user
handoff.

Task-flow checkpoint for NS-4_note-events_01: the published-score-timed WFC
pitch passage and the distinct authored full-event passage are two nonclosing
musical batches. The first is more music-like after its pop repair but still
has reported note/beat conflicts; the second fails the source-free within-bar
harmony control before listening. Both routes stop. The next action changes the
representation by admitting an independent chord context for exact joint
events, rather than changing sequence order, seed or the scored candidates.
The single frozen bar-local branching preflight in ignored
`build/joint-event-context/PREFLIGHT.md` asks whether the existing authored
source controls permit novel complete bars under same-chord constraints. If it
fails its bound, stop the local-bar representation before an API change or WAV.
This is an explicit feasibility decision for criteria 3/4, not a task closure or
new credit.

Ticket Guy completed that one frozen source-free preflight under ignored
`build/joint-event-context/`. Checked FPC 3.2.2 Win32/Win64 reproduced the
three authored source token hashes, exactly replayed 48 four-bundle local bars
through the maintained codec, and leaked no owned blocks. The actual order-2
open model's distinct/authored/novel complete paths by chord context were C
3/3/0, Am 4/3/1, F 6/3/3 and G 3/3/0. Two contexts have a novel path with
both parts and overlap, so `PREFLIGHT.md`'s minimum viability gate passes.
The report SHA-256 is
`ecc0be143b3967647f2e02e8a17dcb2f408744529284920a2fc0b26f00ecf638`.
No recorded audio, inference candidate or WAV was opened or generated.

The integration decision is narrower than that PASS: C and G offer no novel
complete bar, all F novelty leaves the melody projection unchanged, and the
authored controls share one beat-onset grid. Some novel paths use chord-tone
bass inversions; a pitch-class subset alone does not prove a context-defining
root sounds. This vocabulary cannot substantiate the substantial new
two-part composition or improved beat behavior the user is asking for.
Stop the local exact-bar representation before adding a maintained API or
publishing audio. The next implementation path must coordinate independently
generated harmony, rhythm and part choices while retaining exact event gates,
source timing and a prospectively fixed novelty/coherence gate. This is a
bounded decision, not acceptance of NS-4_note-events_01 or new task credit.

Independent QA found a narrower limit in that preflight. Its frozen novelty
comparison was only against authored bars carrying the **same chord label**.
The Am-context new path repeats an authored C bar exactly, and one F-context
new path repeats an authored Am bar. Across all authored complete bars, only
two F-context paths are new; each keeps the F-authored melody and changes one
bass note. The preflight's written same-context PASS remains valid, but the
earlier two-context wording does not establish globally new material in two
contexts. This strengthens the stop decision and earns no credit.

One separately frozen modular named-voice candidate then tested a different
32-second source-free route under ignored `build/joint-voice-graph/`. It used
the maintained harmony, joint rhythm and named part graph, with exact
two-part event codec output and prospectively fixed novelty/coherence gates.
Checked Win32/Win64 source/model/128-cell graph construction passed with zero
leaks. The one seed-1731 Win32 solve returned false before any output gate or
WAV. Its initial `status=190` and pass number were invalid: a Pascal call
formatted the output report in the same argument list that invoked
`TryGenerate`, so evaluation order could read uninitialized fields. A frozen
audit-only same-seed replay changed only report sequencing and recovered the
actual stop: an adjacency contradiction in pass 2 reached the configured
32 per-pass backtrack limit. This is a budgeted solve failure, not proof that
the graph has no solution. No token sequence or listening clip was produced.
Stop this candidate without budget, seed or source retuning. NS-4_note-events_01
and overall credit remain open at 68.65 pending the task-flow checkpoint.

Task-flow checkpoint after the bar-local and modular source-free batches:
neither closed the substantial full-event checkpoint in NS-4_note-events_01.
The bar-local representation offers only two globally new complete bars in
one context, both with the authored melody. The modular 128-cell graph stopped
under its fixed per-pass budget before producing event choices. Do not repeat
either plan with a changed seed, order, budget or source and count it as
progress. Salty Boi independently verified the source bindings, checked runs,
bar novelty correction, invalid initial diagnostic and audit-only stop.

At the pre-acceptance checkpoint, the original note-event task asked for a
bounded generated/rendered example
and an honestly recorded listener verdict; it does not require a positive
coherence verdict. Its engineering fixture is too short to satisfy the
substantial render, while the score-timed 30-second clip does not demonstrate
new onsets or durations from the maintained full-event adapter. The task
remained open pending its bounded adapter deliverable or a criterion split.
The user's distinct demand
for a genuinely coherent original passage now has its own positive gate in
`NS-4_composition_01`, with 1 NS-4 point transferred from the note-event
task's former 2-point allocation. The note-event task retains 1 and recorded
integration retains 2; at that split NS-4 remained 96% and overall credit
remained 68.65.
The new composition task follows the adapter; it does not make personal style
tests or recorded-source inference a core prerequisite.

Accepted bounded adapter checkpoint, 2026-09-24: the task-flow split moved
NS-4_note-events_01's entire substantial full-event WAV, deterministic
artifact/QA and listener criterion to NS-4_composition_01, which also requires
a positive coherence verdict. The retained adapter criteria are exact
two-part event ownership, loss-aware source replay and bounded actual joint
WFC generation. Ticket Guy extended the maintained Pascal focused consumer
without changing its fixed two-sample model, order-2 seed 731 or generator.
Its generated seven-gate/six-bundle output differs from source 0 by one ordered
`(onset,pitch,duration)` tuple in each part; against source 1 the bass differs
by one tuple while the melody exactly replays that source's projection. Both
parts are active, one cross-part simultaneous onset survives, and the prior
retrigger/rest/unequal-duration, clock, deterministic replay and failure
preservation checks still pass. Canonical generated part hashes are
`8119c16b2188e7f544e3faa713a8e67e289e7a4c4b5690299dee2400d5aa12bb`
and `ad8fec2773ea4fd64c6f64b7a3d6bbc187c5ff2916eb8e7346508c9fb0953d0f`.
Checked FPC 3.2.2 Win32/Win64 focused runs match with zero leaks; the run-log
hashes are `878f313e760048e7b450de30285c5e0920b70ee251d2f576f9d718eff4f0da06`
and `a4680442635d070faf3edef666d73d7dd36b055ab9fb89078d989fb784a41cb6`.
Salty Boi independently accepted the per-part projection evidence and scope.
[NS-4_note-events_01](TODO/DONE/NS-4_note-events_01.md) moved to DONE and earned
1 NS-4 point / 0.15 overall: NS-4 is 97%, overall completion 68.80%, and
37 tasks remain open. This acceptance claims a bounded Pascal event adapter,
not a rendered original song, positive listening, or recorded-WAV inference.
The next selected deliverable is [NS-4_composition_01](TODO/DONE/NS-4_composition_01.md).

First composition source preflight, 2026-09-24: the accepted adapter enables
the new source-free composition task, but does not establish an original song.
One ignored Pascal builder under `build/composition-segmented/` authored eight
four-bar C/Am/F/G controls (two per A/A-prime/B/cadence role) and a frozen
16-bar, 32-second schedule. Checked FPC 3.2.2 Win32/Win64 output matched
byte-for-byte with zero leaks; the source builder SHA-256 is
`80cb27be79feb9ad35ca4ec75b783e252a6864e751b92d36df0f0b62aaea6be9`
and schedule SHA-256 is
`ba2645cb5ab3daee558a64c52792a6b28d600701b123d5dfa9ed5525172b695d`.
Each two-bar span has two raw rhythm/bass/melody source paths, but no model
was learned and WFC reachability was not tested. The authored controls cover
within-phrase chord changes but do not demonstrate A G-to-A-prime C,
A-prime G-to-B F or B Am-to-cadence Am role-bound joins. G-to-F has no
authored chord transition at all; G-to-C occurs only within B, and Am
persistence within bars does not cover a phrase boundary. `A_v1` and
`A_prime_v0` also share an identical complete token path. Salty Boi
independently verified the ledgers, zero-leak runs and these limits. Stop
this continuous-frontier source set before inference or audio; do not add
missing examples to this frozen set and call it the same attempt. The next
architecture decision is an explicit phrase-boundary policy with independently
checked musical joins and real WFC variation within phrases. Composition
acceptance remains open; NS-4 stays 97% and overall completion 68.80%.

Composition task-flow reassessment after the continuous-frontier source screen
and a separate phrase-reset audit: the first batch stopped at missing
role-bound joins. The second showed an explicit reset can preserve exact
half-open note gates across all 12 source-control pairings, but the existing
controls fail three frozen role-register checks and include a duplicate whole
token path. Checked FPC 3.2.2 Win32/Win64 reset-audit reports match SHA-256
`c46ca4ab0dda774edfdafa4a82744b2ec20b42523e4fb2a936d33cbe5702f2889`,
with zero leaks. Salty Boi's QA found the first audit checked only four of its
seven declared input hashes; Ticket Guy repaired that private binding and
reran the same metadata checks with all seven verified. No model learning,
solve, audio or listener result occurred. The two batches close no composition
criterion, so do not recycle either source set or alter its registers to claim
a pass.

The changed deliverable is one source-free phrase-reset route under ignored
`build/composition-phrase-reset/QUALIFIED-SOURCE-PLAN.md`: independently
generate four four-bar phrases with separate H/R/bass/melody WFC streams and
explicit gate-safe, harmonic and melodic join checks. A new first-party source
set must first qualify against fixed ranges, rhythm, harmony, source-union
novelty and unique-path checks. One frozen candidate then either meets the
substantial native audio/listening path or stops authored phrase-WFC entirely;
no source, seed or budget repair loop follows a failure. This is a distinct
boundary and source-qualification policy, not a retry of the 128-cell graph.
NS-4_composition_01 remains open at NS-4 97% / overall 68.80%.

The single new first-party phrase-reset source set initially reported a
pre-solve qualification PASS under ignored
`build/composition-phrase-reset/qualified-source/`.
The first Win32 run falsely applied the phrase-final-rest requirement to all
four bar endings and stopped before emitting ledgers; its abrupt exit left
three heap blocks. Ticket Guy corrected that checker, source-ledger
serialization and cleanup without changing `BuildControl` or the source
construction constants. Salty Boi independently compared the before/after
construction and confirmed the corrected Win32/Win64 ledgers match with zero
leaks. All 16 full H/R/bass/melody token paths are distinct, with four rhythm
outlines and four actual melody contours per role. Melody ranges, leap <=12
(observed max 11), bass range/root-fifth, chord-tone strong beats, phrase gate
ends, two-voice final rest and tonic C cadence passed the implemented checks.
The builder SHA-256 is
`6d1e99e62c941bb0325219d7885411f007623c7dc0fa1a2ed8bc6c14b6a1bad9`;
qualification SHA-256 is
`c58f3edbf4c0cc726c64f53ccd8e3b36c62dbd2c74d2e4057ad2543275b20980`.
This was an incomplete check, **not an accepted source qualification**.
Subsequent frozen model preparation exposed attack pitch 36 followed by hold
pitch 43 in `cadence_v0` cells 27-28 and `cadence_v3` cells 28-29. The source
event ledger retains the attack pitch, concealing the mismatch with the frame
tokens. Salty Boi independently traced the bug to the builder's cadence-root
attack override, which changed the emitted cell without updating the retained
previous pitch. The qualifier only checked that a hold followed an active
gate; it did not check exact pitch continuity or agreement between event and
frame ledgers. Its PASS is retracted, and this frozen source set is invalid.

Model preparation trained the A, A-prime and B role models before cadence bass
graph validation rejected seven compatible edges, each emitting the same
attack-36 to hold-43 pair. Cadence melody passed. No candidate solve,
generation, audio or listener verdict occurred. Saved preparation model files
have an extra trailing line feed; the failed exception/Halt path reported
three heap blocks with vendor validation in the stack. These reporting and
cleanup defects do not establish a separate model transition flaw. Under the
frozen `QUALIFIED-SOURCE-PLAN.md` stop condition, **stop the authored
phrase-WFC route**. Do not repair/requalify this source, retune a seed or
budget, or claim composition credit. The task remains open at NS-4 97% and
68.80 overall. The next batch must follow a genuinely different core path,
with source qualification requiring exact hold-pitch and event/frame
agreement if source-free WFC is attempted in the future.

Composition task-flow reassessment, 2026-09-24: the continuous-frontier
source screen and phrase-reset audit closed no criterion; the one frozen
authored phrase-WFC source failed exact pitch continuity before generation.
The next bounded batch changes the representation to WFC-selected short
relative motif/transform choices, with a separately fixed 16-bar form,
beat and chord grammar projecting exact two-part events. This aims at the
user's reported note/beat conflicts while retaining the improved pop-free
native synthesis path. Freeze a prospective policy before any candidate
scoring, allow one source qualification and one candidate, and stop at the
first failed gate rather than iterating a source/seed/budget. The deliverable
is a substantial novel native render and whole-passage listener review if
all structural gates pass. No criterion is yet closed and no credit changes.

The frozen relative-motif batch stopped before a generated WAV. Its plan SHA-256
is `b1ae5aa1a2276ee41ea4a8e9cf88f135fa1901ef8fd82527f151ed4a5615b2ba`.
Checked Win32/Win64 Pascal preflights reproduced four exact 64-token controls,
all 16 motif IDs, 55 branching order-2 contexts and zero leaks. One Win32
candidate solve returned success and persisted a complete 64-token ledger,
SHA-256 `8d660b724104ef4e8afbd4d99202297b4e55130cf631441b7e2867ab5df12ff3`.
The frozen final `K:C:M11` both-rest token then reached a missing case in the
private `MotifDescriptor` projection and raised `Unknown motif ID`. This is an
implementation defect after solve, not a musical-gate failure. No event ledger
or WAV was produced, and no Win64 candidate or listener review ran. The
exceptional exit reported two unfreed blocks. The first private STOP note
incorrectly said no token file persisted; Ticket Guy corrected it without
another solve, and Salty Boi independently verified the frozen source,
hashes, token file, single solve and failure. The corrected ignored STOP note
has SHA-256 `fafe2732385fdd1818384c2ef1dd35b25e252d861d4704b7f44866d565d7e489`.
Honor the prospective no-rerun stop condition: no projection repair or
candidate tuning in this batch. Composition closes no criterion and earns no
credit; NS-4 remains 97%, overall completion 68.80%.

The next selected core path is [NS-3_tempo_04](TODO/NS-3_tempo_04.md), not
another authored composition variant. Its ready source-evidence gate can use
the already inventoried official paired Groove MIDI/audio material only after
exact audio/MIDI correspondence and acoustic hit alignment are verified;
publisher metadata alone is insufficient. Keep the frozen ARTBeaT 02/04
candidate-policy failures and protected evaluation material unchanged. A
bounded source qualification should either supply independently attributable
pulse evidence for a prospective candidate-pool decision or stop without
retuning. This is a change of core prerequisite after the composition stop,
not a claim that beat-level selection or corpus style learning has passed.

The selected GMD paired-audio qualification froze two exact performer/session
disjoint MIDI/WAV pairs and objective clock/onset gates under ignored
`build/gmd-pulse-audio/POLICY.md`, SHA-256
`a5a743b3226713356dfdffa92c4d9d6d6dc74f484e99803ef6291003dd84ac2b`.
The official full archive's HEAD and GET returned the expected
5,111,599,714-byte length and matching ETag, but its one permitted sequential
transfer ended with curl exit 56, connection reset, after 3,949,543,424 bytes
and 371.359 seconds. The incomplete archive has not been opened; no WAV,
acoustic estimate or beat score was produced. The Pascal qualifier compiled
checked FPC 3.2.2 Win32/Win64 but was not run. Salty Boi independently
verified the stop and target outputs. This transport failure closes no
criterion and leaves overall completion 68.80%.

GMD source-evidence task-flow reassessment: its metadata-only source screen
and this full-transfer attempt are two consecutive nonclosing batches. The
next action changes the acquisition method to one byte-range resume from the
exact preserved 3,949,543,424-byte prefix, conditional on the same object
generation/ETag and expected Content-Range, followed by the publisher's full
SHA-256 before any ZIP member opens. Freeze that transport recovery first;
stop if its identity or final hash fails, with no whole-archive restart loop.
The original selected pairs, protected splits, Pascal analysis policy and
ARTBeaT candidate failures stay fixed. A passing transport would only enable
the previously frozen acoustic source qualification, not earn task credit.

GMD transport recovery completed under ignored `build/gmd-pulse-audio/`:
one conditional 206 Range response supplied the exact 1,162,056,290-byte
tail. The publisher full-archive SHA-256
`21559feb2f1c96ca53988fd4d7060b1f2afe1d854fb2a8dcea5ff95cf3cce7e9`
and unchanged prefix SHA-256 passed independent read-only verification.
A PowerShell Int32 overload error in the first post-transfer verifier was
limited to a read-only hash pass; it did not change the archive or cause
another request. The frozen member lookup then stopped at a packaging-path
discrepancy: the official ZIP uses `groove/` before each of the four selected
relative MIDI/WAV paths. Salty Boi independently found exactly one prefixed
entry for each frozen path, with no member stream opened, WAV extracted or
qualifier run. This batch closes no tempo criterion, but the verified source
archive is available. The next bounded action freezes an explicit one-to-one
root-prefix mapping and duplicate check, keeping the original selected
pairs, acoustic gates and protected splits fixed. A mapping failure stops;
otherwise run the previously compiled Pascal qualifier on the two pairs.

The exact `groove/` mapping then passed. Both selected MIDI members matched
their previously verified SHA-256 values, and only the two selected WAVs
were extracted: 24,434,020 and 14,551,374 bytes, each matching its ZIP
member hash. The original qualifier compiled under checked FPC 3.2.2 Win32
and Win64. Its one Win32 development run stopped before WAV decode at
`DecodeMidiNotes(..., DefaultMidiNoteOptions, ...)`: the native decoder
requires an explicit ignore-and-report policy for performance MIDI events.
The MIDI structure/metadata parser passed first, so this is an intentional
source/options contract mismatch, not malformed-source or acoustic evidence.
No Win64 or challenge run followed; no onset score exists. The exceptional
exit reported six unfreed blocks (275 bytes). Salty Boi independently checked
all four member hashes, source/policy identities, compile targets and stop.
The selected-member ledger omitted computed MIDI hashes even though the
extractor checked them; QA recomputed them independently. The earlier
`RECOVERY-RESULT.md` describes the prior pre-extraction checkpoint, while
`QUALIFICATION-STOP.md` and selected-member artifacts describe the current
state. Completion remains 68.80%.

Task-flow reassessment after the prefix-lookup and default-decoder stops:
neither closed a tempo criterion, but the archive and exact pair identities
are now qualified. The next bounded deliverable is **one explicit native
percussion MIDI admission contract** for these same pairs, using the existing
GMD metadata parser's documented ignore-and-report semantics while retaining
all original acoustic clocks, thresholds, splits and source hashes. Freeze
ignored event kinds/count expectations before scoring and stop if the event
contract or first acoustic gate fails. This is a source-admission change,
not beat-candidate fitting or a retry of acoustic thresholds. No further
decoder-option sweep follows.

The one explicit GMD event-admission batch closed its symbolic preflight but
failed the first acoustic source gate. Checked FPC 3.2.2 Win32/Win64 runs for
both selected MIDI pairs preserved their exact note-on/tempo event ledgers,
with matching per-source report bytes and zero reported leaks. The sole
acoustic run was development Win32 on the bound 44.1-kHz stereo WAV
(`87f1e9768630542fead48500212fd85a700b48f4fca25c5556e63d52dca70b4c`):
794 unique localized onset frames, 1,807 distinct MIDI attack ticks, and
770 one-to-one matches within 30 ms, or 42.6121%, below the frozen 80%
coverage gate. Matched-hit median/p95 errors were 4.172336/24.172336 ms.
The report SHA-256 is
`82b446965724eb3de0b826bcb579da7aa2ccfeee22b9432539d61a387998da10`.
The failed exception path reported six unfreed blocks (274 bytes); no
challenge or Win64 acoustic run, retune or retry followed. Salty Boi
independently verified the result. The report labels max raw event tick
214548 beside seconds computed from last gate end tick 137380; that mixed
provenance is a reporting defect, not a matching-clock bug. The current
ignored `ACOUSTIC-STOP.md` records this as the terminal GMD source result;
the earlier `QUALIFICATION-STOP.md` is marked historical.

Stop GMD source qualification here. The result is a failed onset-coverage
gate for this dense mixed-drum pair, not a source-independent beat-candidate
result or proof that the publisher MIDI/WAV are misaligned. Do not tune the
localizer, tolerance, source selector or model on this exposed pair. The
open [NS-3_tempo_04](TODO/NS-3_tempo_04.md) next needs independently
attributable source-pulse evidence from a different qualified setting before
another candidate-pool decision. The protected ARTBeaT evaluation and all
task credit remain unchanged at 68.80% overall.

Disk follow-up: the stopped route left the verified 5,111,599,714-byte GMD
ZIP and two extracted WAVs totaling 38,985,394 bytes under ignored
`build/gmd-pulse-audio/`. The small reports and hashes suffice to retain the
failed result, so these three large files are cleanup candidates. Two
exact-path PowerShell `Remove-Item` attempts were rejected by the automatic
execution approval policy before running; no deletion occurred. Do not
claim reclaimed space. A user-run exact-path cleanup line is needed if the
policy remains in force.

Composition return decision, 2026-09-24: the stopped relative-motif WFC
solve did persist a complete SHA-bound 64-token path. Its missing M11
projector branch is an implementation error after solve. After the separate
GMD source route failed its fixed acoustic gate, a bounded new batch will
replay only that immutable token file through a repaired Pascal projector
and the **unchanged** structural/musical gates, with no WFC call, source,
seed, model or threshold change. Freeze this fixed-token replay separately
and preserve the original candidate-stop evidence. If gates pass, render
one native development WAV for independent QA and whole-passage listening;
otherwise stop before audio. This changes the next action from source
search to a concrete Pythian-generated listening possibility while retaining
the task's maintained-delivery and positive listener criteria. No credit yet.

The fixed-token replay stopped before audio. Its final policy SHA-256 is
`1d17c09f0f8030bd8ba06b40b0524a786c11bd3a87cd195f8e873c06dc6858bc`.
It bound the saved 64-token path SHA-256
`8d660b724104ef4e8afbd4d99202297b4e55130cf631441b7e2867ab5df12ff3`,
all four original control hashes and the original candidate source. With
no WFC solve, the repaired M11 both-rest descriptor projected 105 gates;
the token/event round-trip passed (ledger SHA-256
`f9a67125ebe4a0b621200e69565ae5bf1076219b1527153279a26fecaf513a24`).
The first source-union novelty check then failed: candidate phrase 0 equals
control 1 phrase 0; candidate phrase 2 equals control 3 phrases 0, 1 and 2
after chord labels are stripped. Salty Boi independently verified the exact
motif comparisons and that no WAV or Win64 replay exists. The failed Win32
run exited 1 and reported two unfreed blocks (76 bytes), violating the
zero-leak resource gate too. The private `REPLAY-STOP.md` now binds the exact
compile/run commands, exit code, source and binary hashes (SHA-256
`a99ee0b6d7dab499bb4ba3d72e25756aeb088dcf164bfc6a9ba52fba55f8804d`);
do not mistake the passing round-trip for a
passing composition. Stop this saved path and four-control motif corpus;
no new listening clip or task credit follows. NS-4 stays 97% and overall
completion stays 68.80%. The next composition hypothesis needs a
substantively richer source/structure contract rather than seed/order tuning.

Composition source audit after the copied-phrase stop: Ticket Guy checked the
maintained event learner and existing first-party symbolic demos without running
inference or changing files. The exact joint-event learner has no chord, bar or
form context. Both the voice and ensemble demos contain only two four-bar
controls with nearly fixed onset/rest skeletons, so they can serve as comparison
controls but not as the training corpus for an original 30-second passage. The
stopped motif corpus cannot be reused as a fresh source, and a published-score
replay would not answer the listener's originality concern. This read-only
reassessment closes no task criterion or credit. Next composition work requires
one newly frozen first-party multi-context source and explicit form/chord
projection, with both-part onset, pitch and duration variety, long-range motif
relationships, phrase-union novelty and musical joins checked before audio.
The user's paired review reports one numbered playback as pop-free and more
musical, and the other as better harmonized, while still hearing note/beat
conflicts and judging the result short of a coherent song. Do not assign those numbered
observations to specific filenames until their mapping is confirmed.

The new first-party, form-conditioned composition source under ignored
`build/composition-form-provider/` passed its source-only qualification after
one bounded serialization repair. The first frozen Win32/Win64 builder runs
exited zero but emitted space-padded `beat= 0`, `P 0` and
`control- 0.tokens.txt` despite an internal PASS. Those outputs were
disqualified before model learning. The separately frozen six-site
two-ASCII-digit repair kept all action tables, pairings and gates fixed.
Repaired checked-target source and independent Pascal verifier runs pass with
zero leaks: 24 distinct canonical four-bar controls, 37 branching order-2
contexts and exact parity of 24 token files plus ledger/report. Source report
SHA-256 is `6187d42ba66a116b0bc661528377d622612bb98eb6704227cf2c6f43213de68a`;
ledger SHA-256 is `cf63db38d0aefb553697e396b0be6b9982e8aef3a4ded070758564abf7139a8a`.
Salty Boi independently confirmed the old-to-new formatting-only change and
all source hashes. The independent verifier prints, but does not internally
compare, the report's ledger-hash field; QA checked the field against the
actual ledger. The ignored `SOURCE-RESULT.md` retains the exact freeze and
stop sequence. No WFC model, candidate, WAV or musical verdict exists.
These two source-only batches close no complete composition criterion. The
task-flow reassessment allows one candidate under the already prospectively
fixed form/chord/novelty policy because the source barrier is now removed;
freeze candidate code and learned model identities first, and stop on any
candidate gate miss. NS-4 stays 97%; overall completion stays 68.80%.

The one form-conditioned composition candidate then stopped before audio.
Ticket Guy implemented an ignored Pascal-only candidate and Salty Boi reviewed
the changed gates. Exact source identities were bound before execution;
checked Win32/Win64 compiles passed. Prepare-only runs on both targets returned
zero leaks and identical order-2/open 24-sample model text (209 states,
104 public tokens; SHA-256
`f1e4906037e873048057ce24e0f92f026dae3e5ab30c8800498eafd7a89fd2be`),
prepare report and freeze template. Salty Boi independently checked the
artifacts and identities. The final candidate Pascal source SHA-256 is
`0b6a73fb162a3dc7d8725a0b060c3db8ac0751a9ef2372f8b6506a613bcd85b3`;
the frozen run record and stop evidence are under ignored
`build/composition-form-provider/`.

One checked Win32 candidate run exited 1 at the A WFC solve:
`gssContradiction`, one pass, zero backtracks, zero unfreed blocks. No B solve,
candidate token/event ledger, WAV, Win64 candidate or listener review followed.
Independent read-only review of the frozen token/model/endpoint contract found
that every position-0 `beat=00` token exists only at an open-sample BOS start,
while the frozen `wseFragment` first domain excludes BOS states. This logically
predicts an empty first domain, though the stop artifact carries no position
trace. The same-position masks themselves match the plan. This is a failed
representation/extent policy, not a musical-quality verdict. Respect the
prospective one-candidate stop: no extent switch, source retune, seed change or
repeat solve on this route. The batch closes no composition criterion, so
NS-4 remains 97% and overall completion 68.80%. A future composition attempt
would need a different token/endpoint representation and a bounded reachability
preflight; reselect the next core prerequisite through task flow rather than
cycling another authored composition variant immediately.

The next bounded core-composition batch is an owned, source-free Pascal
form/harmony/event scaffold, not a repair of the stopped beat-tagged WFC
representation. Its prospective ignored `build/composition-grammar-baseline/`
policy fixes two seeds, a 16-bar chord/form schedule, theme/contrast/return
relations, cadence and structural/PCM gates before any run. Ticket Guy built
the checked Win32/Win64 generator and native renderer. Salty Boi's static QA
found and repaired a report-flow defect before execution: the final report
would have overwritten PCM/WAV evidence. The final policy and source SHA-256s
are `1a6be0048cc9d4bb37ce9fb93ef56000b92e372bd78ec7743286ec421b0893d7`
and `2c0857cb29110eb70b0e323954f9ff54073a40545cea140938755d820758abfe`;
the ignored `FREEZE.md` and `RESULT.md` preserve executable identities and
full validation evidence. One fixed Win32 run, one fixed Win64 run and fresh
sibling-directory replays all exited zero with zero reported heap leaks. Both
passages passed structural and PCM gates and reproduced exact event/PCM/WAV
hashes across targets and replays. They are 35.556-second, 44.1-kHz stereo
Pythian renders. Byte-identical copies are numbered `3.wav` and `4.wav` in
the HFS feedback folder for the user's whole-passage judgment of timing,
melody, harmony and originality. Listening is pending. This numeric pass
does not establish a coherent song, recorded learning, WFC composition or
NS-4 task acceptance. Keep NS-4 at 97% and overall completion at 68.80%; do
not retune these seeds after the listener checkpoint.

While that listener verdict is pending, a metadata-first source strategy for
recorded presence stopped on a semantic gate before dataset contents were
opened. The [OpenMIC-2018 publisher](https://zenodo.org/records/1432913)
supplies crowd-reviewed instrument labels and source metadata, but its
[paper](https://archives.ismir.net/ismir2018/paper/000248.pdf) assigns each
yes/no answer to a named instrument anywhere in a 10-second clip. Pythian's
maintained `pythian.presence` reviewed rest requires no audible instrument
in an exact window; a no-guitar clip cannot supply it, and a clip-positive
cannot time attacks or tails. The ignored `build/openmic-presence-source/`
policy, publisher-schema addendum and `STOP.md` preserve the pre-content
decision. One official archive transfer was stopped at 769,896,448 bytes,
renamed `.tgz.partial` and never verified or opened. The checked Pascal
archive verifier compiled but was not run; a partial metadata-gate draft was
not compiled or run. No inference runtime, score or task credit follows.
Automatic approval review rejected deletion of the unverified prefix as
`blocked by policy`; it remains ignored under build. This source route does
not unblock NS-3_notes_05 criterion 3. The composition listening checkpoint
remains independently pending; overall completion stays 68.80%.

Composition listener checkpoint, 2026-09-24: after hearing both full frozen
35.556-second Pythian passages, the user judged `build/feedback/3.wav`
coherent with no stumbling and preferred `4.wav` overall. They judged clip 4
newly composed rather than a recognizable preauthored song. This is a positive
whole-passage verdict for the source-free form/harmony scaffold at its frozen
seeds. It does not establish learned WFC composition or style fidelity. The
scaffold remains ignored/private; maintained Pascal integration, exact native
replay and independent QA remain before `NS-4_composition_01` can earn credit.
NS-4 remains 97% and overall completion remains 68.80% at this checkpoint.

Accepted core composition, 2026-09-24: Ticket Guy moved the frozen first-party
form/harmony generator into portable `src/pythian.music.compose.pas` with an
owned exact note-sequence API, and added the native `pythian.compose` consumer.
The normal core build now compiles and exercises its contrast seed. After one
blocking QA submission exposed output replacement and leaked blocks on report
failure plus incomplete note-end coverage, the CLI was repaired to stage and
restore its WAV/report pair, exit normally on failure and inspect every gate
end. Salty Boi independently accepted checked FPC 3.2.2 Win32/Win64 runs and
fresh replays for both frozen seeds, exact ordered 97/88 gate parity and WAV
identity to the user-reviewed clips, zero heap leaks, preserved sentinel
outputs on forced failure, and all-end jump checks below the declared limit.
The post-freeze 0.005 full-scale note-end limit is a focused QA bound, not a
retuned musical-selection gate. The source phrase union is genuinely empty;
phrase comparisons/copies and WFC model/tokens are explicitly N/A. Full
identities and exact hashes are in [the accepted task](TODO/DONE/NS-4_composition_01.md)
and ignored `build/composition-maintained/QA-MANIFEST.md`. The unreviewed seed-1
smoke output is not acceptance evidence. The task earns +1 NS-4 goal point
(+0.15 overall): NS-4 rises from 97% to **98%**, overall from 68.80% to
**68.95%**, with 36 open and 21 DONE tasks. Recorded musical admission and
[WFC audio integration](TODO/NS-4_integration_01.md) remain open; this result
does not claim either or a personal genre style.

Beat-candidate source reassessment, 2026-09-24: after the stopped GMD
acoustic-coverage route, a metadata-only RWC 2.0 screen identified official
full-mix WAVs, beat annotations and aligned MIDI drum events. The
[audio release](https://zenodo.org/records/18656623) and
[annotation repository](https://github.com/rwc-music/rwc-annotations) list no
isolated drum stem. MIDI transcription is not physical source-pulse truth, so
this source does not close `NS-3_tempo_04` criterion 3 or adjudicate the frozen
ARTBeaT 02/04 misses. No RWC WAV, annotation payload or tracker score was
opened; the 4.1-GB archive was not downloaded. This is one nonclosing source
batch after the GMD stop. Reassess to one bounded, physically separated
recorded challenge using [GuitarSet](https://guitarset.weebly.com/), whose
microphone and six-string pickup recordings have beat and per-string note
annotations. Prospectively bind development player 01
`BN1-129-Eb_comp` and distinct-player/material challenge player 05
`Jazz1-130-D_solo`, exact bytes, clock and source-event eligibility before any
candidate run. Stop at an ambiguous source clock or unavailable attributable
guitar events; preserve the original ARTBeaT gates and protected evaluation.
Criteria 2–5 and all tempo task credit remain open; overall stays 68.95%.

GuitarSet first source gate and identity reassessment, 2026-09-24: the frozen
Pascal preflight compiled on checked FPC 3.2.2 Win32 and stopped at the first
01 microphone SHA check before JAMS event parsing, PCM measurement, tracker
inference or challenge execution. It expected
`76330537c6a88df56c7e338da9dd81d84cbf7f3a5ae7cd1b32a663bded6b76b4`
but found `4f7f2359cc26d32307c8cc6793579d9d5ce602f483194ca079efd719a870b671`.
The expected SHA belongs to the distinct 01 solo microphone file; both
recordings happen to be 1,969,056 bytes. Exact-member re-extraction of the
selected 01 comp WAV from the cached mic archive matches the found SHA, and
the complete archive MD5 matches the [publisher's identity](https://zenodo.org/records/3371780)
`275966d6610ac34999b58426beb119c3`. The original failed report remains
ignored under `build/beat-guitarset-source/`; its exceptional exit reported
zero unfreed blocks. This is an input-ledger transcription error, not acoustic
evidence against the source. Together with the RWC metadata stop, it is two
nonclosing source batches. Reassess to exactly one identity-only correction of
the same selected 01 comp recording, keeping the already frozen source groups,
clock, pickup rule and ≥8/≥3-per-half support gate. Stop at the next source
gate failure; do not substitute a recording or tune thresholds. Criteria 2–5
and task credit stay open, with overall completion 68.95%.

GuitarSet identity repair and decoder stop, 2026-09-24: the one corrected
Win32 run passed the publisher-verified 01 comp mic identity, exact 01 JAMS
identity, original six-channel pickup identity and ZIP member CRC. It then
stopped before PCM or JAMS-event analysis: `TWaveFrameReader` rejects six
channels because its maintained contract admits mono/stereo. The original
identity STOP and corrected decoder STOP are preserved under ignored
`build/beat-guitarset-source/`; no 05, Win64, acoustic support count or beat
candidate score ran, and the exceptional exit reported zero unfreed blocks.
This is a preflight reader mismatch with the declared six-channel source, not
an observed source-acoustic failure. The bounded repair is to adapt the
existing Pascal six-channel PCM16 pickup reader in the ignored qualifier,
with a source-free boundary check before one fixed Win32 source run. Preserve
the same source identities, clock, physical attack rule and ≥8/≥3-per-half
gate. Stop at the next source or acoustic failure; no repeated decoder or
source variants. Tempo criteria and credit remain open at 68.95% overall.

GuitarSet source gate stopped, 2026-09-24: the bounded Pascal six-channel
decoder repair passed a two-frame, six-channel source-free fixture with known
channel RMS and out-of-range rejection. The single fixed checked Win32 source
run then passed 01 mic/JAMS/hex identities, ZIP CRC, equal 984,506-frame
mic/pickup geometry and JAMS parsing. Of 48 annotated beats and 105 guitar
note onsets, 12 onsets met the frozen per-string physical pickup rule. Six
beat positions had such an onset, split 2 in the first half and 4 in the
second. The prospective source gate required ≥8 beats total and ≥3 in each
half, so it failed. The other 93 annotated note onsets remain acoustically
unconfirmed by this rule; no unsupported beat is labeled physically absent.
The ignored `build/beat-guitarset-source/report.tsv` SHA-256 is
`2ca860b55b2fb3f25778cc043aa7a77477d17189951b888cd02a0f7ff9d8dd9c`.
The original identity and decoder STOP reports remain preserved. Both the
self-test and source run reported zero unfreed blocks; no 05 challenge,
Win64 acoustic run, beat tracker, candidate-policy retune or source replacement
followed. This frozen source route is stopped. Together with the preceding
decoder stop, it is two nonclosing batches after identity reassessment; change
course to another ready core task until independently attributable recorded
pulse evidence can qualify `NS-3_tempo_04`. Its criteria 2–5 and all credit
remain open; overall completion stays 68.95%.

Final source QA limitation, 2026-09-24: Salty Boi independently reconciled
the saved GuitarSet TSV ledgers and reran only the source-free six-channel
decoder fixture. The 01-only frozen support failure and zero-leak result hold.
For 21 beat rows with no guitar event inside ±30 ms, the private reporter's
`nearest_signed_error_frames` contains the `High(Int64)` sentinel rather than
an exact nearest signed distance. This is a failed report-field contract, not
source-pulse evidence or a change to the 6/2/4 support count. The stopped
report remains unchanged; do not use that field as an exact error measure or
rerun this source route. The tempo task remains open without credit.

Core WFC composition gap, 2026-09-25: the user's whole-passage verdict on the
accepted `4.wav` remains **newly composed**. That result belongs to the
source-free Pascal composer and its report explicitly records no WFC model.
After the stopped beat-source investigation, the next ready core deliverable is
an actual WFC-selected harmony path projected into a fresh two-part passage.
The new [composition task](TODO/NS-4_composition_02.md) owns a bounded,
untagged 16-bar chord-function model, pre-solve reachability and source-union
novelty gate, checked native replay and a whole-passage listening verdict.
This changes the representation and endpoint policy from the stopped
beat-tagged, motif and full-event composition routes; it does not rerun them.
One of the two unearned NS-4 points moves from
[recorded integration](TODO/NS-4_integration_01.md), which retains every
recorded-provider criterion and one point. NS-4 stays 98%, overall stays
68.95%, with 37 open / 21 DONE tasks. This planning checkpoint selected an
independent portable chord-schedule API; it accepted no WFC model, candidate
or WAV at that time.

First WFC harmony candidate, 2026-09-25: the frozen eight-source order-2
Pascal graph passed exact whole-path and outside-source reachability with 13
states. Its one WFC solve selected `C Am F G | C Am Em G | F G F G | F G C C`,
novel as a complete 16-bar progression and three bars different from the
accepted composer schedule. Of the four aligned chord phrases, 1, 2 and 4
match source-union phrases exactly; only phrase 3 is novel. The caller-schedule
Pascal composer generated 97 events, with unchanged timing and ownership and
8 bass / 9 melody pitch changes. The 35.56-second PCM16 candidate has zero
full-scale samples and a passing note-end jump check. Salty Boi's checked
Win32/Win64 QA reproduced both accepted legacy hashes and the candidate,
checked invalid-chord failure preservation and found zero leaks. The exact
source/policy/model/token/WAV hashes and qualification limits are in ignored
`build/wfc-chord-composition/RESULT.md`. The candidate was first frozen with a
private Pascal WFC probe; the maintained `pythian.wfc.compose` adapter and
`pythian.wfc.composition` consumer now bind the same source, model, token,
event and WAV identities in a one-step checked path. The portable composer
intentionally cannot attest its caller's model identity. Whole-passage
listening remains open; `NS-4_composition_02` earns no credit yet. The
candidate is available as `build/feedback/5.wav` and via the isolated HFS
folder on LAN port 8085.

Maintained WFC composition replay gate, 2026-09-25: the checked Win32/Win64
build now runs `pythian.tests.wfc.composition` in its WFC section. It pins the
eight-source/model/token/event identities, legal and outside-source
reachability, the 2,171-work-unit preflight, exact 9/2/0/8 aligned phrase
source-match counts and all 97 output events. Its invalid-source case preserves
the previous sequence pointer, every owned gate field and every tempo change.
Salty Boi's focused checked FPC 3.2.2 Win32/Win64 runs pass with zero unfreed
blocks. This hardens the maintained boundary but does not replace the pending
whole-passage verdict or earn task credit.

## Cross-task listening and milestone retrospective — 2026-09-25

The user clarified that the next notification threshold is **20 pending
listening reviews accumulated across tasks**, rather than 20 distinct tracks
from the current composition task. Their review time is a parallel resource for
substantial Pythian output. An ignored 20-track, ten-seed-pair composition plan
was superseded before producing any new WAV; its first seed, 731, exposed a
real A/return projection failure. Keep the existing `5.wav` WFC passage as one
pending cross-task item. The queue ledger belongs under ignored `build/` and
must identify the task, exact file and what to hear. No new listening prompt is
due until 20 useful items across task work are ready. Clip 5 is not accepted
until the user judges the whole passage.

The scorecard remains NS-1 100%, NS-2 100%, NS-3 41%, NS-4 98%, NS-5 27%,
NS-6 72%; overall 68.95%. NS-3 and NS-5 account for 29.35 of 31.05 remaining
weighted points. The immediate engineering priority is to protect the accepted
core, then advance a recorded musical-learning prerequisite whose evidence can
close an existing criterion. The bounded seed-731 projection repair is now
complete: source-free melody projection preserves the realized A/return degrees
by a capped search only when the accepted greedy path fails. Checked FPC 3.2.2
Win32/Win64 tests pass with 97 events, two adjustments and 67/100,000 search
nodes; accepted seeds 1731/2731 retain exact event/PCM/WAV hashes on both
targets, WFC caller replay passes, and Salty Boi found zero leaks. No new WAV
was added to the listening queue and no task credit changes.
The note-identity/register and presence paths unlock note events, parts and
many-hour semantic learning, but their documented source screens are stopped;
repeating those selectors or adding acoustic statistics alone is not progress.
The beat-source route likewise needs genuinely attributable pulse evidence.
The WFC composition task has implementation and QA evidence but waits for one
listener verdict. The three user-chosen mixes remain later personal style
tests, not prerequisites to the portable core.

At the next task-selection checkpoint, prefer a genuinely independent,
prospectively frozen recorded-note or context evidence route with a criterion-
closing decision. If no such source is qualified, record the external blocker
and select another ready core task. Each new listening item must come from a
different substantive task result or a distinct musical question that advances
an actual criterion. Do not manufacture tracks solely to reach the batch size,
do not count prior reviewed clips, and do not award credit for a queued item.

## Source-screen stop and candidate-boundary switch — 2026-09-25

Two bounded source checks after the retrospective failed before scoring and
close no acceptance criterion. For `NS-3_tempo_04`, the BeatNet+ paper describes
manually corrected beat/downbeat annotations for MUSDB18 and URSing, which
have isolated stems, but the current public repository's root and recursive
tree contain no `annotations/` directory or `.beats` file. MUSDB18 also
requires academic-use access. No audio or annotation was downloaded, and no
predicted beat was treated as independent reference. For `NS-3_notes_01`, a
frozen four-file University of Iowa flute C4/C5 contrast acquired exact
publisher-linked AIFF and converted WAV bytes under ignored
`build/register-iowa-cycle/`. The first checked Pascal source gate stopped at
44.1-kHz PCM24 stereo against the prospective 96-kHz requirement, before
activity or cycle scoring. The private error-path cleanup was repaired and
the unchanged gate reran with zero leaks. The other files were not scored.

These are two nonclosing source-only batches, so stop this investigation
sequence under task flow. The changed next action is a focused audit of the
already maintained Pascal beat-candidate pool and its caller-visible source,
policy and replay boundary against `NS-3_tempo_04` criterion 4. Implement the
smallest missing usable boundary if the audit finds one; do not reopen a new
recorded-source hunt from these failed screens. The task and overall completion
remain unchanged, and the cross-task listening queue stays at 1/20.

## Beat candidate provenance boundary — 2026-09-25

The focused post-screen batch closed [NS-3_tempo_04](TODO/NS-3_tempo_04.md)
criterion 4. `SelectedBeatClockWindows` now keeps an explicit 0-based source
track-window index and selected candidate index (`-1` for a gap) with the
detached clock input. The track retains all unused candidate alternatives.
The maintained WAV report already binds source SHA-256, frame geometry,
measurement and selection policies, full candidates and selection; clock
segments refer to the same ordered windows. The new native fields make that
link visible to direct Pascal callers, with no confidence or musical-pulse
admission. Checked FPC 3.2.2 Win32/Win64 clock tests pass selection identity,
source owners, gap, replay, detachment and invalid-index preservation. Both
`pythian.beats` and the WFC context-track consumer rebuild on both targets.
Salty Boi's read-only QA found no criterion-4 blocker. Clock JSON relies on
the adjacent track window list for its pool link rather than duplicating it.

This criterion closure resets the consecutive nonclosing-batch count. The
recorded candidate challenge and complete task acceptance remain open, so
the scorecard stays at **68.95%**, with **37 open tasks**. The next useful
step needs attributable source-pulse evidence or another ready recorded
learning prerequisite; do not resume the two stopped source screens. The
cross-task listening queue remains **1/20**.

## Beat candidate changed-path validation — 2026-09-25

[NS-3_tempo_04](TODO/NS-3_tempo_04.md) criterion 5 now closes after focused
checked FPC 3.2.2 Win32/Win64 beat-track and clock fixtures, affected CLI
builds and an actual authored-WAV consumer run. The unchanged source is
44,100-Hz stereo, 617,400 frames, SHA-256
`2b6ff5b2abb62117022a59bc2c6173fd63846b9c62982acd57d907238a3ae2cc`.
`pythian.beats --track --clock step` emits 14 local windows, 24 tracked pulse
positions and 24 reconstructed clock positions. Repeating the run on each
target reproduces its exact JSON bytes; Win32 SHA-256 is
`3160b08840fd363403fb43df56ffbc62a72c6f25ae2249b86734b409cf6ba478`,
Win64 is `f0bd0284ee1f2e80f6f99b61159a8892da709da0256f614bfc0afb449715850`.
Small cross-target floating values differ; source identity, candidate indices
and discrete track/clock frames agree. The earlier Win32 build's track JSON
predates the current phase-family policy and was not used as a byte baseline.
The present authored lab retains regular 24/24, polyphonic tracked 20/20 and
changing-rate tracked 24/24, while exposing the wrong 192-BPM polyphonic
fixed-grid top candidate with 19 extras. Previously recorded deceptive and
polyrhythm controls remain as regression evidence for the unchanged model.
Salty Boi found no criterion-5 blocker. Exact commands and hashes are in
ignored `build/beat-pool-link/RESULT.md`.

Criteria 1–3 and the full task remain open for attributable source-separated
recorded pulse evidence. No beat-level admission, task credit or scorecard
change follows. The cross-task listening queue remains **1/20**.

## Style assignment correction and presence source stop — 2026-09-25

The [style specification](STYLE-CARDS.md#status-and-reference-requirements)
now assigns its three current preference references to the complete mixes the
user personally selected. The older 30-second A/B/C excerpt cards remain
explicitly historical screens and cannot set preference gates. Exact private
mix identities stay under ignored `build/`; song cuts, timed traits and
independent evaluation remain unverified. This corrects the active assignment
without closing an `NS-5_evaluation_01` criterion or changing credit.

A read-only check of the publisher's
[MAESTRO v3.0](https://magenta.tensorflow.org/datasets/maestro) documentation
found aligned piano audio/MIDI and pedal control but no independently reviewed
exact-window audible no-instrument rest. MIDI release plus low PCM energy does
not authorize the maintained `ReferenceReviewed` assertion. No package or
metadata was acquired, and no presence score ran. This repeats the evidence
gap of the stopped MAPS route, so stop further paired-MIDI source searching for
[NS-3_notes_05](TODO/NS-3_notes_05.md) and follow a different ready core task.
The task, milestone score and listening queue remain unchanged.

## Milestone critical-path retrospective — 2026-09-25

The current ledger is **68.95 overall / 37 open tasks**. NS-3 and NS-5 hold
29.35 of the 31.05 remaining weighted points. The immediately ready tasks
were reviewed against their *remaining* acceptance gates, rather than their
amount of completed preparation:

| Ready task | Next evidence that could close it | Current decision |
| --- | --- | --- |
| `NS-4_composition_02` | Whole-passage verdict on the already QA-checked WFC passage | Keep `5.wav` as one pending cross-task item; do not prompt below 20 useful pending reviews. |
| `NS-3_notes_05` | A source-separated recorded case with independently supported exact audible positive and no-instrument rest, plus a fresh disjoint evaluation case | Stop paired-MIDI source searches. The existing rain/applause review says **no pitched music**; it does not by itself assert an exact generic no-instrument rest for `ReferenceReviewed=True`. |
| `NS-3_tempo_04` | Qualified source-separated recorded pulse challenge for criteria 1–3 | Retain the accepted boundary and consumer for criteria 4–5; do not recycle failed source gates or infer physical pulses from beat labels alone. |
| `NS-3_context_01` and `NS-3_notes_01` | Distinct source-grounded key/register observations that pass their frozen recorded gates | Keep stopped rank/threshold and source-geometry variants stopped. |
| `NS-5_evaluation_01` | Verified group/song intervals and curator-supported timed musical traits for the three complete preference mixes | Retain the corrected full-mix assignment; defer musical gates while those observations are missing. |

This checkpoint finds no currently justified scorer retune or source-only rerun
that would close an additional criterion. The next work batch must name a
qualified independent evidence route or a newly observed implementation defect
before opening one of these stopped investigations. The listening queue stays
**1/20**; HFS currently returns HTTP 200 for the queued file on the LAN.
No task moved to DONE and no credit changed in this retrospective.

## Multi-recording scale deliverable split — 2026-09-25

The prepared 2.3222053373-hour, three-source development workload can be
observed by the accepted Pascal WAV producer in five adjacent scopes. The
earlier `NS-5_scale_01` preparation and whole-array rejection batches closed
no criterion; its missing admitted-note-to-learner bridge remains owned by
`NS-3_notes_03`. The raw work can produce an independently useful bounded
multi-recording reader and exact source-bound packet before that bridge exists.
The [new raw task](TODO/DONE/NS-5_scale_03.md) therefore owns maintained corpus
reading plus actual five-job observation/cost qualification; the
[original scale task](TODO/NS-5_scale_01.md) retains admission, semantic
aggregation, model-capacity and full-pipeline budgets. Its original four
unearned NS-5 points are now raw **1** and semantic **3**, totaling the same
0.80 overall points. No task or criterion closed, so the score stays **68.95**;
open task files rise from 37 to **38**. The first raw batch stops before a long
run if source/scope geometry, existing single-job limits or the maintained
reader's failure tests fail. Ticket Guy owns only the new Pascal reader,
fixture and inference build hook; the primary owns source identity, workload
execution and accounting. Salty Boi reviews the combined components when both
are ready. The cross-task listening queue remains **1/20**.

## Raw-corpus code and frozen long-run stop — 2026-09-25

The new [raw scale task](TODO/DONE/NS-5_scale_03.md) now has a maintained Pascal
multi-recording reader, auditor, checked-target fixture and inference build
hook. They preserve recording group/source/scope identity and reject bad
adjacency, wrong estimator/policy/binding, corrupted checksums or centers.
The auditor also verifies actual source WAV hash and geometry. Its two-source
pilot reads exactly 12,429 rows from the full Pixel Sprinter and Opening Theme
prepared recordings. Salty Boi's checked Win32/Win64 QA caught and then
cleared fractional manifest integers, clean exception finalization and a
wrong exact-integer source frame count, with zero leaks. The code boundary is
ready for the declared workload; the pilot is not many-hour acceptance.

The first frozen long WAV-C scope then stopped on the predeclared 5-second
observing-stall gate at 1,120,750 ms, with 327,744/360,000 rows completed and
5,032 ms since the last progress publication. The supervisor published no C1
artifact and reported zero unfreed blocks. The five-job schedule stopped at
that first failure; no full-corpus read, cost qualification or task credit is
claimed. Current shared progress cannot distinguish a backend stall from source
or output I/O, so the next useful raw-scale action is a bounded phase-specific
diagnosis before another frozen attempt. Exact private identities, commands,
pilot checks and failure are in ignored `build/scale-raw-corpus/`.

One predeclared 128-row Pascal probe at the first unreported center completed
in 22,797 ms under the same source/model/policy and five-second gate. It did
not reproduce a local audio-window stall. Ticket Guy's read-only path review
found the worker reports each completed row before a synchronous 32-row append;
the failed count is exactly on that boundary. An output write is plausible but
unproven. One telemetry-only attempt will mark append start/completion without
publishing a heartbeat inside the write or changing limits; Salty Boi will
check the changed boundary before its long run.

This retro keeps the critical-path priority intact: `NS-3_notes_03` remains the
semantic admission bottleneck, while the separately implemented raw reader can
serve it once the long workload passes. The user-selected style mixes are
preference test material, not core prerequisites or accepted genres. The WFC
composition listening item stays queued under the cross-task **1/20** rule;
no source clip or unfinished raw run is added to that queue. The milestone
score remains **68.95**, with **38 open tasks**.

## Bounded Pascal raw corpus accepted — 2026-09-25

The instrumented, separately frozen follow-up completed C1, C2 and C3 with
360,000, 360,000 and 103,566 raw rows. The earlier full Pixel Sprinter and
Opening Theme jobs contribute 3,429 and 9,000. The maintained Win64 Pascal
auditor then verified all three WAV hashes and actual geometry, the five PINF
identities/checksums/center sequences, contiguous scope coverage and exactly
**835,995** rows. Unique original-clock coverage is **2.3222053373 hours**,
with C still one conservative group and unresolved internal song cuts. The
successful five jobs took **2,683,156 ms**, below the frozen 8,510,000-ms
ceiling, and their PINFs use **1,217,210,335 bytes**, below the 2-GiB raw-cache
limit. Largest worker-private peak was **6,586,368 bytes**; all per-job setup,
scope-time and private limits passed. Producer source verification ran ten
complete source passes across the five jobs. Exact per-artifact hashes, source
and command identities are in ignored `build/scale-raw-corpus/RESULT.md`.

The first C1 stall cost **1,120,750 ms** separately and published no artifact;
the short local-window probe passed, but the original intermittent stall's
exact cause remains unknown. Checked telemetry retains the original five-second
stall gate, and Salty Boi verified a byte-identical real Pixel replay plus the
final arithmetic/scope evidence. Exact cold-setup values for Pixel/Opening were
not retained, though their published artifacts passed the producer's enforced
30-second setup limit. This is accepted raw observation infrastructure only:
no admitted notes, semantic learning, style quality or complete pipeline result
is inferred.

[NS-5_scale_03](TODO/DONE/NS-5_scale_03.md) moves to DONE, earning **+1 NS-5**
and **+0.20 overall**. NS-5 is **28%**, overall completion **69.15%**, with
**37 open / 22 DONE** tasks. The next critical dependency remains
[NS-3_notes_03](TODO/NS-3_notes_03.md) through source-grounded register and
presence admission; [semantic scale](TODO/NS-5_scale_01.md) stays open until
that bridge and actual learning qualify. The cross-task listening queue remains
**1/20**, with no source label or raw observation added.

## Note-register stop and semantic-bridge split — 2026-09-25

After raw corpus acceptance, one genuinely independent flute-tone source
qualified eight exact publisher WAVs, including same-published-player C4/C5
and vibrato pairs. The prospectively frozen Pascal source gate passed 40/40
fixed activity windows. Its necessary one-versus-two-C5-period contrast then
passed 5/5 on each first-player nonvibrato C4/C5 and vibrato C4 member, but
only **2/5** on the first-player vibrato C5 member against a required 4/5.
Stop this cycle-ratio proposal there, before scoring the second published
player ID. No blind note estimate, Spring score, accepted register observation
or task credit follows. Checked FPC 3.2.2 Win32 reported zero leaks; exact
private source hashes and residuals remain in ignored
`build/register-yorita-cycle/`. The collection is described by the
[publisher](https://www.brinckerhoff.org/flute-tones/index.html) and its
[Cal Poly thesis](https://digitalcommons.calpoly.edu/theses/1308/); the
publisher's numeric player IDs are not treated as proven independent people.

The task retro leaves the note-register and generic-presence source routes
stopped. To advance the critical path without another speculative source
screen, split an independently useful admitted-note-to-WFC bridge from
[NS-3_notes_03](TODO/NS-3_notes_03.md) into
[NS-3_notes_06](TODO/DONE/NS-3_notes_06.md). The new task will use source-bound
published reference events to prove original-frame ownership, hard unknown/
recording training boundaries, saved WFC learning/reload and deterministic
solve. The phrase task retains actual **inferred** events, independent
precision/coverage/onset/full-note gates and the final audible learned result.
Original unearned **+5 NS-3** credit is redistributed **+1 bridge / +4 phrase**;
no credit is earned by splitting. The ledger remains **69.15 overall / 38 open
tasks**, with the cross-task Pythian listening queue **1/20**. Ticket Guy owns
the bounded Pascal bridge; Salty Boi owns its QA. No reviewed source clip or
diagnostic render is added to the listening queue.

## Source-bound admitted-note WFC bridge accepted — 2026-09-25

[NS-3_notes_06](TODO/DONE/NS-3_notes_06.md) now has a maintained Pascal
adapter, a focused checked fixture in the build hook and a separately frozen
two-work reference integration. The adapter retains original-frame WAV/group/
recording and published annotation identities, projects endpoints to a shared
integer-millisecond WFC duration clock, and splits independent training runs
at unknown, unannotated and recording boundaries. Unknown is excluded from
the learned vocabulary/output; explicit silence remains trainable. It rejects
malformed ownership/intervals and the 33rd run. A linear evidence builder
records exact source coordinates, excluded gaps and run ownership.

Checked FPC 3.2.2 Win32/Win64 fixtures pass the changed boundaries, 16-kHz/
44.1-kHz equal-duration mapping, exact 100-ms token with 99/101-ms exclusions,
source-leading/trailing gaps, canonical reload, deterministic three-token
solve and failure preservation, with zero leaks. The private Pascal integration
verified exact WAV and published Notes bytes from different development-exposed
URMP Spring/Dance works, trained **22 runs / 23 pitch spans** across **2
sources/groups**, saved/reloaded the on-disk model and evidence, and solved two
seed-731 pitch-duration tokens. Win32, Win64 and repeated runs agree byte for
byte: model SHA-256 `c7602485034a094001d905887ab17cb914758861a86da31955ec18ccbf1cb2f2`,
evidence `22eea1992a95107a2d965474d5b4c9fdcfde5b58511125560b79fc80cb2319ca`,
tokens `162344203556a49ed158aaf2a17bc093af12daf6da1797a71e95942f77648c32`.
Salty Boi's final QA cleared the scale and exact-token issues; private policy,
source hashes, commands and logs are under ignored `build/admitted-wfc-bridge/`
and `build/admitted-note-bridge/`.

The task earns **+1 NS-3 / +0.25 overall**, raising NS-3 to **42%** and total
completion to **69.40%**. The catalog now has **37 open / 23 DONE** tasks.
This accepts a generic learner bridge using externally supplied reference
events; it does not accept WAV note inference, acoustically measured rests,
phrase accuracy, musical quality or a listening verdict. The next critical
core decision remains recorded note identity and generic presence with truly
independent physical evidence; [NS-3_notes_03](TODO/NS-3_notes_03.md) must
feed **actual inferred** events to this bridge and pass its held-out phrase
and audible gates before semantic scale can claim admitted music. The cross-task
Pythian listening queue remains **1/20**.

## Milestone retro and independent pulse-reference gate — 2026-09-25

The prior admitted-note WFC bridge closed a useful core prerequisite, but it
did not remove the recorded-evidence bottleneck. Current completion remains
**69.40 overall**, NS-3 **42%**, NS-4 **98%**, NS-5 **28%**, and **37 open / 23
DONE** tasks. The cross-task substantial Pythian listening queue is still
**1/20**: the WFC harmony `5.wav` has completed engineering QA but awaits the
user's whole-passage verdict for `NS-4_composition_02`. Do not count old
answered files or seed variants toward that queue.

The active core chains are (a) recorded pitch and generic presence, then event
decisions and actual inferred-note WFC phrases; (b) source-attributable beat
candidates, then beat level, changing clocks and context; and (c) the separate
WFC composition listening gate. Raw multi-hour acoustic observations are
accepted, but semantic scale remains downstream of inferred phrases. The
three personal style corpora and their cards do not block core function. The
failed octave, acoustic-rest and pulse source routes retain their stop decisions;
repeating a threshold or another source-only window search would not close an
acceptance criterion.

The selected next batch was `NS-3_tempo_04` criteria 1–3: qualify one
independent live-source pulse reference before candidate scoring. The
publisher's [KRAISLER dataset](https://zenodo.org/records/21082251) supplies
isolated dry piano/violin stems, directly captured piano performance MIDI and
manually refined beat timestamps. The ignored pre-acquisition policy at
`build/kraisler-reference/POLICY.md` fixed archive integrity, IDs 01/02 for
development and 03/04 for candidate challenge, the first 30 seconds, and a
30-ms MIDI/beat plus 10-ms dry-piano physical-attack gate. Pascal verified the
full 1,558,287,213-byte publisher MD5, 389 unique ZIP entries and 20 complete
source groups. Before acoustic scoring, the policy recorded two source-schema
repairs: publisher Table 2 supplies artistic identity while the archive CSV
binds files, and exact tick-zero channel-prefix/one-hour SMPTE metadata is
neutralized only in private memory so the maintained MIDI importer can read
relative note/tempo timing. The first frozen group passed at 43 supported
beats, 18/25 across halves. The second failed at 3, split 3/0, below the
frozen 8/3/3 minimum. Unsupported beats remain `unknown`; 03/04 were not
acoustically scored, and the candidate tracker was never run. Both scored runs
reported zero leaks. No criterion or credit closes, and ARTBeaT 02/04 remain
unresolved. The archive, extracted WAVs and transfer fragments were removed
after retaining identity logs, freeing 3,218,220,770 bytes. The publisher page
lists CC BY 4.0 while also stating a commercial-use restriction; the private
qualification produced no accepted learned result.

This and the earlier BeatNet+ source inventory are two nonclosing pulse-source
batches. The next action changes from speculative source hunting to preserving
the accepted candidate/clock contract and waiting for genuinely attributable
physical pulse evidence before criterion 1–3 scoring. Ticket Guy's read-only
task-graph retro found no other ready core task that can earn acceptance without
an external source or the pending substantial composition listen. Do not fill
the cross-task 20-item listening queue with variants; `5.wav` remains its one
pending item. The catalog's accepted-credit figure was corrected from 13.65 to
13.90 so it now matches 55.5 + 13.90 = 69.40; actual completion did not change.

## Beat-candidate deliverable split — 2026-09-25

The two nonclosing pulse-source batches triggered a task-size reassessment.
The maintained authored-control candidate pool/clock link is an independently
usable Pascal result; the source-separated recorded challenge is a different
acceptance boundary. [NS-3_tempo_05](TODO/DONE/NS-3_tempo_05.md) was assigned authored
fast/half/double and phase alternatives, controlled loss categories, retained
pool/clock identity and checked consumer replay. [NS-3_tempo_04](TODO/NS-3_tempo_04.md)
retains source-qualified recorded candidate recall, physical/unknown
attribution and challenge QA, and depends on 05. Every original criterion maps
across those two scopes. The original unearned **+2 NS-3 / +0.50 overall** is
redistributed **+1/+1 NS-3 / +0.25/+0.25 overall**; no credit is earned by
splitting. The catalog temporarily has **38 open / 23 DONE** tasks and remains
**69.40 overall**.

A static artifact audit found the maintained Win32/Win64 pool and clock
boundary plus authored 24/24, 20/20 and 24/24 lab results, but its retained
report does not yet establish the exact 60/120/240 alternatives or complete
source-free loss taxonomy on the maintained path. Ticket Guy owns one bounded
Pascal authored-control validation and its checked two-target evidence; Salty
Boi will review the complete scoped result. If those cases need model retuning,
stop and leave 05 open. Recorded source qualification remains stopped; the
cross-task Pythian listening queue remains **1/20**.

## Authored beat-candidate contract accepted — 2026-09-25

[NS-3_tempo_05](TODO/DONE/NS-3_tempo_05.md) now closes the bounded
source-independent candidate deliverable. The existing maintained Pascal pool,
track and clock path retains alternative candidates and exact source/policy
links; focused checked Win32/Win64 consumers and authored-WAV replay remain
accepted. A pre-run SHA-bound authored Pascal control added the exact
60/120/240-BPM and competing-phase checks plus separate no-admitted-input,
insufficient-event, no-positive-fit, local eligibility rejection, named
suppression and capacity cases. Both checked FPC 3.2.2 targets passed with
zero leaks and identical discrete counts; the private policy, commands, hashes
and logs are in ignored `build/beat-candidate-authored-acceptance/`.
Salty Boi accepted the complete scoped result after checking the test/policy
hashes and existing consumer evidence. Empty input means no admitted onset,
not acoustic source absence; recorded challenge recall and musical beat-level
selection remain open in [NS-3_tempo_04](TODO/NS-3_tempo_04.md) and its
successors.

The task earns **+1 NS-3 / +0.25 overall**, raising NS-3 to **43%** and total
completion to **69.65%**. The 61-task catalog now has **37 open / 24 DONE**;
accepted task credit is **14.15** above the 55.5 baseline. The recorded-source
route stays stopped, while `5.wav` remains the sole pending item in the
cross-task Pythian listening queue (**1/20**). This closure does not advance
recorded learning, genre quality or the pending listener verdict.

## Core milestone retrospective — 2026-09-25

After the authored beat-candidate closure, the task graph still has **37 open /
24 DONE** and **69.65%** credited. NS-3 recorded learning and NS-5 style/corpus
quality hold **28.65 of the 30.35** remaining overall points. The numerical
summary in MILESTONES.md was corrected to match the current scorecard; this is
bookkeeping, not new acceptance.

The shortest core dependency route is source-grounded note activity and pitch
register (`NS-3_notes_05` and `NS-3_notes_01`), then event decisions and
independent phrases (`NS-3_notes_02` and `NS-3_notes_03`). Those phrases unlock
recorded part learning and the semantic workload; harmony and groove also need
accepted context and timing. Existing
development failures and source-screen stop decisions still apply: no new
blind pitch cue, generic recorded rest, or independent physical beat reference
was established in this retrospective. Do not turn authored controls, metadata
silence, missing annotations or a source preference label into acoustic truth.
Resume the presence decision only with a prospectively separated recording
that independently supports both audible activity and a generic rest; resume
register inference only with a new, blind discriminating cue that can face the
frozen flute gates. Neither condition is satisfied by the present files.
The separate `NS-3_tempo_04` recorded challenge resumes only with attributable
pulse evidence; personal style cards remain downstream of grounded musical
observations. No extra task or percentage was created to represent preparation.

The core WFC composition path is engineered and queued as `5.wav` for the
user's whole-passage verdict. It is one genuine cross-task listening item out
of the requested **20**, not 20 variants of one task. Other ready tasks have no
substantial new Pythian output yet. Continue independent work when new
evidence can close an actual acceptance boundary; preserve the current
listening queue and do not claim NS-4 closure without the verdict.

## Presence-source quality checkpoint — 2026-09-25

Two read-only source screens since the core retrospective closed no acceptance
criterion in [NS-3_notes_05](TODO/NS-3_notes_05.md). DEMAND names outdoor noise
scenes; BUT ReverbDB separately records room background `silence`, but its
publisher does not certify exact-window absence of audible instruments and
notes a radio in one office setup. Neither archive was acquired or scored.
Stop publisher-label-only noise/room source hunting. The external unblock is
an independently reviewed exact generic no-instrument interval in a
source-separated recording; absent that, preserve `unknown` and the existing
decision rule. Recorded note presence, downstream phrases and style work stay
open. No task credit changes: **69.65%**, **37 open / 24 DONE**; the genuine
cross-task Pythian listening queue remains **1/20**.
