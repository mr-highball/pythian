# Studio: Library → Selection → Generate

[Goal](GOAL.md) · [Tasks](TODO/README.md) · [LAN setup](LAN-REVIEW-SERVICE.md) · [Work](WORK.md)

## 1. Library

Put private WAV recordings inside `local-audio/collections/<collection>/`, or
choose **Music folder** to see the configured folder. `PYTHIAN_AUDIO_LIBRARY`
can select another private root containing `collections/`. Recordings, catalogs,
answers and generated music stay outside source control.

Search tracks or styles, choose a collection, and press **Add** beside the music
you want. The listing uses metadata and bounded WAV headers; it does not download
or analyze entire tracks. Play/pause auditions a recording without adding it.
Each track's **N clips** button opens its reusable saved clips, with original
time ranges, labels, independent audio previews and **Use this clip**. These clips
remain available across playlists. Whole-track selection collapses child rows;
switch it off to choose individual clips. Removing a choice from a playlist does
not delete the saved clip file.

**Add music** imports a WAV. **Record** opens microphone recording directly.
Stop recording, inspect it, then add it to a collection. Phone recording needs
the existing [HTTPS setup](LAN-REVIEW-SERVICE.md#phone-microphone-over-the-lan).
The dialog also retains optional analysis, Experimental MIDI/note preview and
effects tools. These are optional exploration, not required Generate steps.
Importing identical audio reuses its catalog recording and existing title.

## 2. Selection

Tracks marked for learning teach Pythian. Whole tracks are selected by default.
Choose **Choose clip** to save one or several passages instead. Audition or edit a clip,
switch back to the whole recording, or remove a track. The selected duration
updates immediately. Playback never changes training inclusion.

Optional **Choose by label** selects matching collection/whole-track or saved clip
labels. Preview the named tracks and exact ranges before applying. A matching
whole track takes priority over its clips; otherwise the matching clips teach.
Other saved choices stay in the playlist, marked **Not selected for learning**.
Overlapping matching clips must be edited before applying. Labels match exactly;
they select material and do not infer a genre's instruments. Add optional clip
labels beside Start/End. Manual inclusion edits clear the label rule.

Changes save automatically. **Playlists** reopens saved choices or starts a new
playlist. Earlier projects open as separate playlists; original snapshots and
review answers stay preserved. Saving choices never starts learning.

Each saved clip becomes an independent WAV automatically. **Clip file saved**
and **Save WAV** appear when it is ready. Copying runs on the host with progress,
Stop and retry, so the phone can leave and reconnect. Labels and influence remain
linked without copying the audio again. Existing ranges are saved when used.
Learning verifies and reads these clip files; it does not rescan their full parent
recordings. A saved clip still works when its original is unavailable. Missing or
changed clip data fails explicitly instead of silently substituting the original.

The host's configured `PYTHIAN_STUDIO_ARTIFACT_ROOT` holds canonical WAVs and
`<catalog-namespace>/clips/<clip-id>.json` origin receipts. Each receipt links the
original metadata snapshot, exact source-frame range, sample clock, audio hash
and known license/provenance. Audio preserves source sample bytes and format;
collection/clip labels remain in immutable playlist snapshots. The original file
is retained. Library discovery metadata is not claimed as a full audio digest.

## 3. Generate

**Songs** in the header finds recent completed generations and named output
playlists. **Save to playlist** names the exact current mix without rendering or
copying audio. **Download WAV** saves a copy to the device. Output playlists are
separate from the input playlists used to teach Pythian.

**Save style** keeps a finished track's learned musical providers, instruments
and effects under a name you choose. **Use a saved style** opens a small chooser
in Generate. Choose one, set the track length and generate without reading or
analyzing the original recordings again. **Learn from my selection** switches
back; changing the selected music also returns to playlist learning. Saving a
style changes metadata only and never starts a job. Older tracks without a
retained model explain that a new generation is needed. Edited-style saving and
selective blending remain unfinished under the [style task](TODO/NS-5_instrumental-styles_01.md);
an edited performance does not offer its unchanged parent recipe as its own style.
These controls are being qualified in the isolated QA slot; WORK records the
live deployment separately.

While generation starts or runs, a visible status and **Stop generation** remain
available across the three steps. Returning from background reconnects to the
same job. Stop intent is retained when a submitted request loses its response;
reconnecting does not silently submit that request again.

**More music controls · optional** explains and opens authored musical experiments.
It is not needed for ordinary Library → Selection → Generate.

Choose **Track length** in seconds, minutes or hours, then press **Generate music**.
The default is two minutes; plans from two seconds to24hours are supported.
The displayed disk estimate includes the mix, six parts and a1second effect tail.
Output storage grows with length; musical lookahead and PCM working blocks stay
bounded. Native admission checks free disk space before starting.
Optional **Track influence**
gives particular recordings more weight in learning; it is not playback volume.
The one action verifies/prepares selected sources, analyzes their included time,
learns musical providers, solves the WFC musical graph and performs Pythian
instruments. No manual labeling, proposal approval or authored starter is required.

The host computer keeps working if the phone sleeps or the page closes. Reopen
the same playlist to reconnect. One continuous workflow shows **Learn your music →
Plan the track → Synthesize audio → Save the result**. During learning, the counter
adds selected audio time across every recording or clip, including reused analysis.
During synthesis, it counts one persistent performance feeding mix and all six
instrument parts. Final saving counts all seven files and result publication.
File reads,
pitch/beat detection and intermediate saves update the activity without resetting
that progress. These are workflow steps, not an elapsed-time estimate;
the line below the bar shows the current file bytes, audio frames or work count.
Whole-track learning checks the full file's identity. Saved clips check only
their independent audio. Original comparison identifies the selected range in
the parent track; learning receipts keep local clip and original coordinates.
**Stop generation** cancels at a native checkpoint. A reconnect retries the saved
request rather than starting a duplicate job.

Play the result and **Save WAV** in the same step. **Compare an original excerpt**
plays a bounded reference from the actual selection. Playback pauses other app
players. **What Pythian learned from** shows analyzed and model-used duration
separately, plus the active label, source influence, proposed roles and excluded
recordings. A changed playlist is explicitly distinguished from an older result.

**Change sounds** makes another version of a finished track. Choose a Bass,
Harmony or Lead sound, then **Create new version**. Notes, drums, length, seed
and learning stay the same, including when your playlist has since changed.
Compare **Before** and **After**, or use **Back to previous version**. Stopping
the new render keeps the previous version available. The host continues working
after the page closes. Older tracks without saved notes need one new generation
before this control is available. The four current oscillator choices are a
starting point; deeper instrument and effect recipes remain planned.

**Change notes** changes selected parts within a time range. Start with the parts
you want to vary; **More choices** optionally limits each pitched part's MIDI
range or allows chords/rhythm to change. Choices must fit notes already in the
saved model. Keep other parts selected only when you allow them to change.
The requested range follows musical steps and the result displays its actual
bounds. Internal planning chunks do not pin old notes inside your passage.
Pythian reports a conflict or a valid unchanged result honestly. These follow-ups
reuse the saved models without learning again, retain the current instruments
and preserve the previous version. **Hear individual parts** compares the same
part Before/After; collapsing playback tools pauses their audio.

## Optional: Musical laboratory

Press **Lab** in the header to try authored music without recordings. The main
Library → Selection → Generate flow remains the place to learn from your music.
The laboratory uses an authored symbolic starter, actual WFC decisions and the
same native six-part synthesis, progress, Stop and playback as ordinary jobs.

**Music** sets key, tempo and length, from one to32 four-beat bars. **Parts**
sets each part's sound or mix, plus pitched note ranges, activity, strength and
length. **Feel** fills editable energy/density/tension preferences; **Apply**
changes settings and starts no job. Follow the starter fixes its chords/rhythm;
Let WFC vary releases them. Preferences cannot override a hard pitch limit.

**Structure** optionally arranges named sections. Add a section, or repeat an
earlier one and choose the parts to keep. A repeat uses its source length.
Generated results can **Hear section** or **Change this section** through the
existing player/editor. Section changes may override that section's retained
parts; other sections stay saved. **Hear whole track** resumes full playback.
Experimental structure currently requires neutral activity/chord preferences
and100% global note strength/length. Each section has **Energy**, from0 soft
through50 neutral to100 strong. It changes new instrument attacks; held notes
keep ringing. Repeated parts keep their notes/rhythm while new attacks use the
current section's energy. Section density remains in progress.

Settings save automatically as named experiments. Reopen them in **Saved
experiments**. Only **Generate experiment** starts music. Successive generations
retain the last completed version for **Before/After**, including individual
parts. **Back to previous version** recovers it after a conflict or Stop. Closing
the page leaves native work running; returning reconnects to that same run.
**Experiment settings** returns to the form, and **Back to playlist** returns to
your recording-based choices. Contextual **?** help closes back to the form.
These settings are authored/operator choices, never claimed as WAV learning.

## Current experimental limits

The [long-generation task is accepted](TODO/DONE/NS-6_instrumental-streams_01.md):
actual hour playback/seeking, ordinary two-minute generation/reopen and24hour
admission/cancellation pass. A full24hour render has not been tested. Unsupported
learned constraints can still fail with an explanation; duration is never silently
truncated or satisfied with source fragments. Stop checks native checkpoints;
an I/O-blocked worker may need its supervisor's cancellation grace period.

All included audio is traversed in bounded windows. Pitch and pulse suggestions
use the first eight seconds of each window; spectral measurements cover the whole
window. A shared budget of 1,024 known eighth-note cells samples musical bars
across the selection. Analyzed duration is therefore larger than model-used
duration for long recordings. Unknown material and omitted time remain explicit.
Very short unsupported selections may be rejected with their choices preserved.

The arrangements are **Experimental**. Chroma, periodic pitches and spectral changes
propose bass, harmony, lead and percussion; this does not recover isolated source
instruments. The result performs primary Pythian instruments, never windows cut
from the training mix. Labels provide context until explicitly used in **Choose
by label**, where they select the sources/clips that teach. Influence changes
actual training counts. A genre label alone does not choose an instrument.

Source verification and first analysis can take time. Saved proposal caches are
reused. This workstation also showed seconds of latency closing small files on
its E drive; retain this measured limitation when assessing job speed.

Open **Songs**, open a finished track, then choose **Sounds & effects** to edit
its instruments and racks. **Create new version** keeps the saved notes and
learning model; compare Before/After or expand **Hear individual parts**.
**Saved sound setups** saves the complete sound settings without starting a job.
The editor is optional; the main Library → Selection → Generate flow stays simple.
See the accepted [sound-design scope](TODO/DONE/NS-2_sound-design_01.md).

The [graph workbench](TODO/NS-4_graph-workbench_01.md), reusable styles/blends and guided
[synthesis reviews](TODO/NS-6_synthesis-reviews_01.md) remain open work. Their
library foundations do not imply that the simple Studio exposes every control.
Optional correction/bypass of recording-derived musical proposals remains
[open](TODO/NS-3_experimental-learning_01.md); importing/analyzing recordings and
automatic playlist learning do not require that editor.
Historical operator workflows are retained in [the work history](WORK-HISTORY.md),
not required steps in this interface.
