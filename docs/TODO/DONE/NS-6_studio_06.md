# NS-6_studio_06 — Import or record audio and explore its analysis

[Task index](../README.md) · [Task flow](../../TASKFLOW.MD) · [North star](../../MILESTONES.md#ns-6)

**Description:**

Allow WAV upload or explicit microphone capture, original listening and supported
library analysis before an optional Save to collection. Expose the existing
single-pitch tracker through MIDI download and synthesized playback alongside
the original, marked **Experimental**. Operator listening is the development
feedback loop; absent scientific acceptance must not hide runnable tooling.
This does not establish reliable polyphonic transcription or restart stopped
scientific experiments.

Execution status: accepted engineering outcome — 2026-10-01. Big Boss accepts
bounded WAV upload, generated-device microphone lifecycle, native inspection,
experimental MIDI/audio comparison, feedback and explicit collection saving.
Closing evidence: independent browser
`build/salty-studio-browser-20261001/VERDICT.txt` and
`FINAL-BROWSER-IDENTITIES.json`, with retained native evidence under
`build/salty-studio-native-20261001/` (stable FPC 3.2.2 Win32/Win64 and
matched pas2js 3.3.1). Source and staged candidate identities are exactly those
recorded in the manifests; this is not a new published-revision or build claim.
This task's engineering work is complete; stop at this accepted scope. No musical or
scientific inference acceptance or duplicate credit follows.
Generated-device browser controls verify mechanics; actual physical human
microphone use was not observed. Big Boss accepts the current engineering
criteria with that evidence limit explicitly retained.

North star: NS-6. Outcome owner: OPERATOR-STUDIO.
Completion credit: 2 goal percentage points (0.20 overall points).
Basis: two unearned points transfer from delivery_03 (six to four); its complete
packaging and extraction criteria remain required. Scoping earns no credit.

**Acceptance Criteria:**

- AC1: Provide Import WAV with bounded size/format validation and explicit
  upload/progress/failure/retry states. Temporary inputs do not silently join
  the durable source collection or a training corpus.
- AC2: Provide explicit Start/Stop microphone capture with permission, live
  duration/level feedback, declared recording bounds and a discard action.
  Release device tracks after stop/cancel/navigation and prevent unintended
  monitoring feedback. Detect insecure or unsupported browsers before capture;
  provide the supported secure-context route without weakening browser security.
- AC3: Audition the original and explore current measured/candidate analyses
  with source-time overlays. Run the existing single-pitch tracker, export its
  candidate notes as MIDI and synthesize them for comparison. Use a small
  Experimental badge, with settings and limitations behind optional details.
  Permit the operator to try mixed material without a purity declaration or
  validation gate. Preserve original clock, channel, conversion and analysis
  parameters, exclude unknown spans from note export, and retain those spans
  separately. A rendered preview earns no automatic transcription acceptance.
  Save operator feedback against the exact source, job and settings.
- AC4: Explicit Save to collection publishes verified source identity and honest
  provenance, retaining capture/import metadata and any derived lineage. Retry
  cannot duplicate assets; discard and failed upload leave no selectable partial
  source. Subsequent training requires explicit corpus selection/admission.
- AC5: Independently validate actual WAV import, secure-context capture lifecycle,
  denial/cancel/oversize/corrupt input, playback/analysis and optional Save/reload
  on desktop and narrow layout. State any physical-device or microphone evidence
  that still requires the operator; do not substitute generated test audio for
  an actual human microphone-use verdict.

**Blockers**

- [NS-6_studio_04.md](NS-6_studio_04.md)

**Dev Notes:**

- 2026-10-01, Neo: Big Boss's native temporary-upload/capture store verifies WAV
  input before inspect/save, retains interrupted inputs for explicit discard and
  requires deliberate collection Save. The existing single-pitch tracker now
  supplies an explicit experimental MIDI/native synthesized comparison for the
  first bounded eight seconds, retaining original clock/channel, declared
  conversion, unknown spans and exact-job feedback. It does not admit inferred
  notes for training or claim accepted transcription. Silence produces no fake
  note output. The browser surface offers Import WAV or explicit microphone
  Start/Stop, with bounded Pascal PCM encoding and a Pascal-generated AudioWorklet;
  its native browser ABI/lifecycle still requires current independent verification.
- 2026-10-01, Neo: independent Salty native QA passes 53 controls on each stable
  Win32/Win64 target with zero leaks: chunk retry, quota/path/corruption boundaries,
  temporary isolation, explicit Save/dedup/discard, real MIDI decode and replay,
  silence and stereo-channel/original-duration mapping. Evidence is under
  `build/studio-chief/` and `build/salty-studio-native-20261001/`; submitted native
  failures remain zero. Root provides the same-port host loopback route for the
  browser's secure-context requirement, without changing LAN phone security.
  Independent current upload/AudioWorklet permission/denial/navigation/cleanup,
  desktop/narrow preview/feedback and the operator's actual microphone verdict
  remain pending. Generated device controls cannot replace a human verdict, and
  these checks award no task or stopped-inference credit.

- 2026-09-30, Big Boss: user explicitly wants to hear and battle-test existing
  tooling, regardless of scientific validation. The earlier blanket unavailable
  message concealed a missing adapter: native pitch tracks and MIDI export already
  exist. This task now explicitly owns their experimental Studio integration.
  Reliable recorded inference remains in [notes_01](../NS-3_notes_01.md),
  [notes_05](../NS-3_notes_05.md), [notes_02](../NS-3_notes_02.md) and
  [notes_03](../NS-3_notes_03.md). No new credit or relaxed inference gate follows.
- 2026-09-30, Big Boss: user's explicit microphone/WAV exploration requirement
  is distinct from filesystem discovery and effects. Browser capture requires a
  secure context under [Media Capture and Streams](https://www.w3.org/TR/mediacapture-streams/).
  Prefer current AudioWorklet capture over the deprecated ScriptProcessor path
  described in the [Web Audio specification](https://webaudio.github.io/web-audio-api/).
  Capture/encoding remains Pascal-owned through the browser adapter; analysis
  stays native Pascal. No external inference runtime or new science is authorized.

- 2026-10-01, final acceptance — Big Boss accepts this task's scoped engineering
  outcome after independent native and browser evidence. See
  `build/salty-studio-browser-20261001/VERDICT.txt` and
  `FINAL-BROWSER-IDENTITIES.json`, plus retained
  `build/salty-studio-native-20261001/` results on stable FPC 3.2.2 Win32/Win64
  and matched pas2js 3.3.1. The global verdict's sole pending cancellation-display
  case belongs to studio_02. Native submitted failures: 0; browser submitted
  failures: 0 for this batch. QA runner/oracle corrections remain privately
  preserved and are not production failures; historical counters are unchanged.
  Prior pending notes are historical. Recorded source/staged
  identities remain authoritative; no new published revision is claimed.
  Award only the existing task allocation; no musical/inference acceptance.
  Generated-device microphone evidence covers browser mechanics and cleanup.
  Actual physical human microphone use was not observed; it is not replaced
  by the generated signal or claimed as a human-use verdict.
