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

Everything in this playlist teaches Pythian. Whole tracks are selected by default.
Choose **Choose clip** to save one or several passages instead. Audition or edit a clip,
switch back to the whole recording, or remove a track. The selected duration
updates immediately. Playback never changes training inclusion.

Changes save automatically. **Playlists** reopens saved choices or starts a new
playlist. Earlier projects open as separate playlists; original snapshots and
review answers stay preserved. Saving choices never starts learning.

## 3. Generate

Choose **Track length** and press **Generate music**. Optional **Track influence**
gives particular recordings more weight in learning; it is not playback volume.
The one action verifies/prepares selected sources, analyzes their included time,
learns musical providers, solves the WFC musical graph and performs Pythian
instruments. No manual labeling, proposal approval or authored starter is required.

The host computer keeps working if the phone sleeps or the page closes. Reopen
the same playlist to reconnect. One continuous workflow shows **Learn your music →
Plan the track → Synthesize audio → Save the result**. During learning, the counter
adds selected audio time across every recording or clip, including reused analysis.
During synthesis, it counts the mix and all instrument parts together. File reads,
pitch/beat detection and intermediate saves update the activity without resetting
that progress. These are workflow steps, not an elapsed-time estimate;
**Stop generation** cancels at a native checkpoint. A reconnect retries the saved
request rather than starting a duplicate job.

Play the result and **Save WAV** in the same step. **Compare an original excerpt**
plays a bounded reference from the actual selection. Playback pauses other app
players. **What Pythian learned from** shows analyzed and model-used duration
separately. A changed playlist is explicitly distinguished from an older result.

## Current experimental limits

This finite path accepts **2–30 second previews**, plus a release/effect tail.
Flexible minutes/hours of instrumental output remain the
[long-generation task](TODO/NS-6_instrumental-streams_01.md); the duration field
does not silently truncate those requests or switch to source fragments.

All included audio is traversed in bounded windows. Pitch and pulse suggestions
use the first eight seconds of each window; spectral measurements cover the whole
window. A shared budget of 1,024 known eighth-note cells samples musical bars
across the selection. Analyzed duration is therefore larger than model-used
duration for long recordings. Unknown material and omitted time remain explicit.
Very short unsupported selections may be rejected with their choices preserved.

The arrangements are **Experimental**. Chroma, periodic pitches and spectral changes
propose bass, harmony, lead and percussion; this does not recover isolated source
instruments. The result performs primary Pythian instruments, never windows cut
from the training mix. Style tags currently provide collection context; influence
changes actual training counts. A genre label alone does not choose an instrument.

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
