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

## 3. Generate

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

The [graph workbench](TODO/NS-4_graph-workbench_01.md),
[musical controls](TODO/NS-4_graph-controls_01.md),
[sound design](TODO/NS-2_sound-design_01.md), reusable styles/blends and guided
[synthesis reviews](TODO/NS-6_synthesis-reviews_01.md) remain open work. Their
library foundations do not imply that the simple Studio exposes every control.
Historical operator workflows are retained in [the work history](WORK-HISTORY.md),
not required steps in this interface.
