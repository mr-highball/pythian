# NS-6_studio_14 — Play custom-duration generation as it is produced

[Task index](README.md) · [Task flow](../TASKFLOW.MD) · [North star](../MILESTONES.md#ns-6)

**Description:**

Replace the fixed audition-length menu with useful defaults and explicit custom
duration. Expose the native generation session through Studio so the operator
can start hearing output promptly and choose minutes or hours without waiting
for a complete file. Keep a short-review workflow and its saved feedback usable.

North star: NS-6. Outcome owner: OPERATOR-STUDIO.
Completion credit: 3 goal percentage points (0.30 overall points).
Basis: one unearned delivery_04 point and two delivery_05 points transfer here;
both donor tasks retain all acceptance requirements.
Credit is earned only after all criteria and prerequisites pass.

Execution status: selected after the native session's exact-code acceptance.
Big Boss owns this solo batch.
Next deliverable: custom duration, native streamed playback
and comprehensible controls/status in Studio. Closing evidence: two-minute,
two-hour and twenty-four-hour plans, bounded early playback/buffering, pause,
cancel/disconnect, replay and desktop/narrow interaction. Stop at unbounded
buffer/disk growth or a browser-only synthesis replacement.

**Acceptance Criteria:**

- AC1: Operator can enter a duration in familiar units, with useful defaults;
  two minutes, two hours and twenty-four hours are supported session requests.
  Show source coverage separately from output duration, seed and supported
  generation controls. No artificial 20–40-second-only product restriction.
- AC2: Native Pascal owns generation/DSP. The browser is a bounded audio consumer;
  first playback does not wait for total generation, and memory/disk/read-ahead
  limits do not scale with declared session length. Clearly show preparing,
  buffering, playing, paused, completed, stopped and actionable failures.
- AC3: Pause/resume, stop, page exit/disconnect and server restart have defined
  behavior with no orphan producer or looping audio. Unrelated app operations
  remain usable. Preserve model/source/seed identity and progress without
  presenting a restarted or different stream as an exact continuation.
- AC4: Retain traceable review excerpts and explicit export choices with honest
  limits. Existing project, short auditions and listening answers remain usable;
  long audio is not a single unbounded browser buffer or invalid oversized RIFF.
- AC5: Native service and actual Codex Browser desktop/narrow tests cover
  startup, continuous playback, buffering/backpressure, pause/stop and failure
  recovery on authored inputs. Record measured budgets and exactly which full
  durations were rendered. Physical device and sustained musical-quality verdicts
  retain their existing owners and are not inferred from a duration control.

**Blockers**

- [NS-4_streaming_01.md](DONE/NS-4_streaming_01.md)
- [NS-6_studio_02.md](DONE/NS-6_studio_02.md)
- [NS-6_studio_08.md](DONE/NS-6_studio_08.md)

**Dev Notes:**

- 2026-10-02, Big Boss: the native jobs parser and worker enforce twenty-to-forty
  seconds and publish listening assets only after full WAV completion. Editing
  the HTML choices cannot provide the requested dynamic playback. This task is
  distinct from the already accepted short-audition job contract and from NS-5
  musical continuity/structure acceptance.
